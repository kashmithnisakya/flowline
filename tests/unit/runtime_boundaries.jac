"""Verify the pinned runtime's durable rows and callback counts before submission."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { uuid4 }
import from jaclang.data.store { TxnIsolation }
import from jaclang.runtime.exceptions { PartialCommitError, ReadOnlyRetry }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.archetype { NodeAnchor }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface as Jac }
import from jaclang.server.session { Session, unit_writes_recorded }

node BoundaryCounter {
    has n: int = 0;
}

def dynamic(value: any) -> any {
    return value;
}

def session(ctx: ExecutionContext) -> Session {
    mem = ctx.mem;
    assert isinstance(mem, Session);
    return mem;
}

def counter(ctx: ExecutionContext, value: int) -> NodeAnchor {
    anchor = dynamic(BoundaryCounter(n=value)).__jac__ as NodeAnchor;
    anchor.persistent = True;
    ctx.mem.put(anchor);
    return anchor;
}

def stored(ctx: ExecutionContext, id: any) -> str | None {
    probe = dynamic(ctx.mem.store).new_session();
    try {
        rows = probe.rows(
            "SELECT props->'archetype'->>'n' FROM anchors WHERE id=CAST(:id AS uuid)",
            {"id": str(id)}
        );
    } finally {
        probe.close();
    }
    return str(rows[0][0]) if rows else None;
}

def fail_commit_once(sess: Session) -> list[int] {
    store = dynamic(sess.store);
    commit = store.commit;
    left = [1];
    def fail {
        if left[0] and store.in_txn() {
            left[0] -= 1;
            store.rollback();
            raise PgWireError({"C": "40001", "M": "injected outer conflict"});
        }
        commit();
    }
    store.commit = fail;
    return left;
}

test "durable nested and explicit work is never repeated by an outer retry" {
    for variant in ["shared", "child", "explicit"] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = ExecutionContext(
                base_path_dir=td, full_target_path=str(Path(td) / "boundary.jac")
            );
            JacRuntime.exec_ctx = ctx;
            child = ExecutionContext(_parent=ctx, _own_session=True)
                if variant == "child"
                else ctx;
            try {
                sess = session(ctx);
                inner_session = session(child);
                parent = counter(ctx, 0);
                sess.commit();
                calls: list[int] = [];
                callbacks: list[int] = [];
                ids: list[any] = [];
                faults: list[list[int]] = [];
                def outer {
                    calls.append(1);
                    def inner {
                        ids.append(counter(child, 42).ensure_id());
                        if variant == "explicit" {
                            Jac.on_commit(lambda() { callbacks.append(1); });
                        } else {
                            inner_session.on_commit(lambda() { callbacks.append(1); });
                        }
                    }
                    if variant == "explicit" {
                        inner();
                        Jac.commit();
                    } else {
                        inner_session.run_request(inner);
                    }
                    current = sess.get(parent.ensure_id());
                    assert current is not None;
                    dynamic(current.archetype).n = 1;
                    if len(calls) == 1 {
                        faults.append(fail_commit_once(sess));
                    }
                }
                failure = "";
                try {
                    sess.run_request(outer);
                } except Exception as e {
                    failure = type(e).__name__;
                }
                assert failure == "PartialCommitError" , (variant, failure);
                assert calls == [1] and callbacks == [1] , variant;
                assert faults == [[0]] and len(ids) == 1 , variant;
                assert stored(child, ids[0]) == "42" , variant;
                assert stored(ctx, parent.ensure_id()) == "0" , variant;
            } finally {
                if child is not ctx {
                    child.close();
                }
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    }
}

test "callback graph writes survive serialization without repeating the body or effect" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "callback.jac")
        );
        JacRuntime.exec_ctx = ctx;
        try {
            sess = session(ctx);
            counter(ctx, 0);
            sess.commit();
            calls: list[int] = [];
            callbacks: list[int] = [];
            ids: list[any] = [];
            left = [1];
            def body {
                calls.append(1);
                ids.append(counter(ctx, 7).ensure_id());
                def effect {
                    callbacks.append(1);
                    ids.append(counter(ctx, 42).ensure_id());
                    store = dynamic(sess.store);
                    upsert = store.upsert;
                    def fail(rows: any) -> any {
                        if left[0] {
                            left[0] -= 1;
                            store.rollback();
                            raise PgWireError(
                                {"C": "40001", "M": "injected callback conflict"}
                            );
                        }
                        return upsert(rows);
                    }
                    store.upsert = fail;
                    try {
                        sess.read_barrier();
                    } finally {
                        store.upsert = upsert;
                    }
                }
                sess.on_commit(effect);
            }
            failure = "";
            try {
                sess.run_request(body);
            } except Exception as e {
                failure = type(e).__name__;
            }
            assert not failure , failure;
            assert calls == [1] and callbacks == [1] and left == [0];
            assert [stored(ctx, id) for id in ids] == ["7", "42"];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "a partially committed child callback cannot report parent success" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "child-callback.jac")
        );
        JacRuntime.exec_ctx = ctx;
        child = ExecutionContext(_parent=ctx, _own_session=True);
        try {
            sess = session(ctx);
            other = session(child);
            parent = counter(child, 0);
            other.commit();
            body_calls: list[int] = [];
            callback_calls: list[int] = [];
            child_calls: list[int] = [];
            ids: list[any] = [];
            faults: list[list[int]] = [];
            def body {
                body_calls.append(1);
                ids.append(counter(ctx, 7).ensure_id());
                def callback {
                    callback_calls.append(1);
                    def nested {
                        def inner {
                            child_calls.append(1);
                            ids.append(counter(child, 42).ensure_id());
                        }
                        other.run_request(inner);
                        current = other.get(parent.ensure_id());
                        assert current is not None;
                        dynamic(current.archetype).n = 1;
                        faults.append(fail_commit_once(other));
                    }
                    other.run_request(nested);
                }
                sess.on_commit(callback);
            }
            failure = "";
            try {
                sess.run_request(body);
            } except Exception as e {
                failure = type(e).__name__;
            }
            assert failure == "PartialCommitError" , failure;
            assert body_calls == [1] and callback_calls == [1] and child_calls == [1];
            assert faults == [[0]] and len(ids) == 2;
            assert [stored(child, id) for id in ids] == ["7", "42"];
            assert stored(child, parent.ensure_id()) == "0";
        } finally {
            child.close();
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


def context(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "boundary.jac")
    );
}

test "staged nested callback writes persist before returning to the outer unit" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = context(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = session(ctx);
            ids: list[any] = [];
            calls: list[int] = [];
            callbacks: list[int] = [];
            def outer {
                calls.append(1);
                def inner {
                    ids.append(counter(ctx, 7).ensure_id());
                    def effect {
                        callbacks.append(1);
                        ids.append(counter(ctx, 42).ensure_id());
                    }
                    sess.on_commit(effect);
                }
                sess.run_request(inner);
                assert [stored(ctx, id) for id in ids] == ["7", "42"];
                raise ValueError("outer body failed after the nested call");
            }
            partial = False;
            try {
                sess.run_request(outer);
            } except PartialCommitError {
                partial = True;
            }
            assert partial and calls == [1] and callbacks == [1];
            assert [stored(ctx, id) for id in ids] == ["7", "42"];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "raw callback writes never disappear behind a successful write-set retry" {
    for failure in ["commit", "flush"] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = context(td);
            JacRuntime.exec_ctx = ctx;
            try {
                sess = session(ctx);
                store = dynamic(sess.store);
                key = uuid4().hex;
                ids: list[any] = [];
                calls: list[int] = [];
                callbacks: list[int] = [];
                left = [1];
                real_upsert = store.upsert;
                def fail_upsert(rows: any) -> any {
                    if left[0] {
                        left[0] -= 1;
                        store.rollback();
                        raise PgWireError({"C": "40001", "M": "raw callback conflict"});
                    }
                    return real_upsert(rows);
                }
                def body {
                    calls.append(1);
                    ids.append(counter(ctx, 7).ensure_id());
                    def effect {
                        callbacks.append(1);
                        store.rows(
                            "INSERT INTO kv_state (key, value) VALUES (:k, 'v')",
                            {"k": key}
                        );
                        if failure == "commit" {
                            fail_commit_once(sess);
                        } else {
                            counter(ctx, 42);
                            store.upsert = fail_upsert;
                            sess.read_barrier();
                        }
                    }
                    sess.on_commit(effect);
                }
                partial = False;
                try {
                    sess.run_request(body);
                } except PartialCommitError {
                    partial = True;
                } finally {
                    store.upsert = real_upsert;
                }
                assert partial , "opaque callback SQL must fail closed after rollback";
                assert calls == [1] and callbacks == [1];
                assert stored(ctx, ids[0]) == "7";
                probe = store.new_session();
                try {
                    rows = probe.rows(
                        "SELECT count(*) FROM kv_state WHERE key = :k", {"k": key}
                    );
                    assert int(rows[0][0]) == 0;
                } finally {
                    probe.close();
                }
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    }
}

test "raw writes promote keyed read-tier units by safe request replay" {
    for snapshot in [False, True] {
        with TemporaryDirectory() as td {
            sess = Session(base_path=td, target_path=td + "/raw-writer.jac");
            try {
                store = dynamic(sess.store);
                key = "raw-writer:" + uuid4().hex;
                value_key = uuid4().hex;
                sess.unit_enter(key);
                retried = False;
                try {
                    if snapshot {
                        sess.read_barrier();
                    }
                    store.rows(
                        "INSERT INTO kv_state (key, value) VALUES (:k, 'v')",
                        {"k": value_key}
                    );
                } except ReadOnlyRetry {
                    retried = True;
                    sess.abort();
                    sess.take_ro_retry();
                } finally {
                    sess.unit_exit();
                }
                assert retried and unit_writes_recorded(key);
                sess.unit_enter(key);
                try {
                    store.rows(
                        "INSERT INTO kv_state (key, value) VALUES (:k, 'v')",
                        {"k": value_key}
                    );
                    assert store.txn_isolation() is TxnIsolation.SERIALIZABLE;
                    sess.commit();
                } finally {
                    sess.unit_exit();
                }
                probe = store.new_session();
                try {
                    rows = probe.rows(
                        "SELECT count(*) FROM kv_state WHERE key = :k", {"k": value_key}
                    );
                    assert int(rows[0][0]) == 1;
                } finally {
                    probe.close();
                }
            } finally {
                sess.close();
            }
        }
    }
}
