"""Ambient kinetic dot-grid canvas: dots lean toward the cursor, ripple from
clicks, spring back. Pointer events pass through, the loop pauses when the tab
is hidden, reduced-motion gets a static grid. Place inside a `relative`
container before the content; pass className for masks (e.g. a bottom fade)."""

import from "react" { useEffect }
import from ...lib.utils { cn }

def:pub KineticGrid(props: any) -> JsxElement {
    has canvasRef: Ref[any] = Ref();

    useEffect(
        lambda {
            canvas: any = canvasRef.current;
            win: any = window;
            doc: any = document;
            if not canvas {
                return lambda {};
            }
            ctx: any = canvas.getContext("2d");
            st: dict[str, any] = {
                "mx": -10000.0,
                "my": -10000.0,
                "w": 0.0,
                "h": 0.0,
                "dpr": 1.0,
                "raf": 0,
                "last": 0.0,
                "dirty": True,
                "running": False,
                "reduced": False,
                "ripples": []
            };
            media = win.matchMedia("(prefers-reduced-motion: reduce)");
            st["reduced"] = bool(media.matches);

            resize = lambda {
                rect: any = canvas.getBoundingClientRect();
                dpr: float = win.devicePixelRatio or 1.0;
                st["w"] = rect.width;
                st["h"] = rect.height;
                st["dpr"] = dpr;
                canvas.width = Math.round(rect.width * dpr);
                canvas.height = Math.round(rect.height * dpr);
            };

            draw = lambda {
                ctx.setTransform(st["dpr"], 0, 0, st["dpr"], 0, 0);
                ctx.clearRect(0.0, 0.0, st["w"], st["h"]);
                isDark = doc.documentElement.classList.contains("dark");
                now: float = win.performance.now();
                keep: list = [];
                for r in st["ripples"] {
                    age0: float = now - r["t0"];
                    if age0 < 1100.0 {
                        keep.append(r);
                    }
                }
                st["ripples"] = keep;
                pitch = 26.0;
                w: float = st["w"];
                h: float = st["h"];
                mx: float = st["mx"];
                my: float = st["my"];
                x = 13.0;
                while x < w + pitch {
                    y = 13.0;
                    while y < h + pitch {
                        px = x;
                        py = y;
                        boost = 0.0;
                        dxm = mx - x;
                        dym = my - y;
                        dm: float = Math.sqrt(dxm * dxm + dym * dym);
                        if dm < 150.0 and dm > 0.01 {
                            f = 1.0 - dm / 150.0;
                            f = f * f;
                            px = x + (dxm / dm) * f * 10.0;
                            py = y + (dym / dm) * f * 10.0;
                            boost = f * 0.5;
                        }
                        for r in st["ripples"] {
                            rt: float = r["t0"];
                            rx: float = r["x"];
                            ry: float = r["y"];
                            age = (now - rt) / 1000.0;
                            radius = age * 750.0;
                            dxr = x - rx;
                            dyr = y - ry;
                            dr: float = Math.sqrt(dxr * dxr + dyr * dyr);
                            band: float = Math.abs(dr - radius);
                            if band < 90.0 and dr > 0.01 {
                                decay: float = Math.exp(-2.6 * age);
                                kick = (1.0 - band / 90.0) * 9.0 * decay;
                                px = px + (dxr / dr) * kick;
                                py = py + (dyr / dr) * kick;
                                boost = boost + (1.0 - band / 90.0) * 0.65 * decay;
                            }
                        }
                        a = 0.10 + boost * 0.28;
                        if a > 0.4 {
                            a = 0.4;
                        }
                        if isDark {
                            ctx.fillStyle = "rgba(230, 237, 235, " + str(a) + ")";
                        } else {
                            ctx.fillStyle = "rgba(20, 18, 15, " + str(a) + ")";
                        }
                        ctx.beginPath();
                        ctx.arc(px, py, 1.1 + boost * 0.9, 0.0, 6.2832);
                        ctx.fill();
                        y = y + pitch;
                    }
                    x = x + pitch;
                }
            };

            # Self-rescheduling via the dict lookup so the lambda can reach
            # itself without a forward reference. Repaint only when something
            # changed, plus a slow cadence so theme switches repaint too.
            holder: dict[str, any] = {"tick": 0};
            holder["tick"] = lambda {
                now: float = win.performance.now();
                last: float = st["last"];
                if st["dirty"]
                    or len(st["ripples"]) > 0
                    or (now - last) > 800.0 {
                    st["dirty"] = False;
                    st["last"] = now;
                    draw();
                }
                if st["running"] {
                    st["raf"] = win.requestAnimationFrame(holder["tick"]);
                }
            };
            start = lambda {
                if not st["running"] {
                    st["running"] = True;
                    st["raf"] = win.requestAnimationFrame(holder["tick"]);
                }
            };
            stop = lambda {
                st["running"] = False;
                win.cancelAnimationFrame(st["raf"]);
            };

            onMove = lambda (e: any) {
                rect: any = canvas.getBoundingClientRect();
                st["mx"] = e.clientX - rect.left;
                st["my"] = e.clientY - rect.top;
                st["dirty"] = True;
            };
            onClick = lambda (e: any) {
                rect: any = canvas.getBoundingClientRect();
                ex: float = e.clientX;
                ey: float = e.clientY;
                left: float = rect.left;
                top: float = rect.top;
                cx = ex - left;
                cy = ey - top;
                wNow: float = st["w"];
                hNow: float = st["h"];
                if cx >= 0.0 and cx <= wNow and cy >= 0.0 and cy <= hNow {
                    grown: list = st["ripples"];
                    grown = grown + [
                        {"x": cx, "y": cy, "t0": win.performance.now()}
                    ];
                    st["ripples"] = grown;
                    st["dirty"] = True;
                }
            };
            onResize = lambda {
                resize();
                st["dirty"] = True;
            };
            onVis = lambda {
                if doc.hidden {
                    stop();
                } else {
                    start();
                }
            };

            resize();
            draw();
            if not st["reduced"] {
                win.addEventListener("mousemove", onMove);
                win.addEventListener("click", onClick);
            }
            win.addEventListener("resize", onResize);
            doc.addEventListener("visibilitychange", onVis);
            start();

            return lambda {
                stop();
                if not st["reduced"] {
                    win.removeEventListener("mousemove", onMove);
                    win.removeEventListener("click", onClick);
                }
                win.removeEventListener("resize", onResize);
                doc.removeEventListener("visibilitychange", onVis);
            };
        },
        []
    );

    return <canvas
        ref={canvasRef}
        aria-hidden="true"
        className={cn(
            "pointer-events-none absolute inset-0 h-full w-full",
            props["className"]
        )}
    />;
}
