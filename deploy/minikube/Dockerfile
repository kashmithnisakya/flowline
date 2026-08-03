# standup on Kubernetes, built by hand because `jac start --scale` cannot run
# from a macOS host (see deploy/minikube/README.md).
#
# Build from the REPO ROOT so the context includes the whole project:
#   docker build -f deploy/minikube/Dockerfile -t standup-app:local .
FROM jaseci/jaclang:0.34.9

WORKDIR /app
COPY . /app

# Resolve the Python and npm closures at build time so pod startup is just the
# server coming up. The `mcp` extras are deliberately not installed: the app
# never imports them, and they only matter on a developer's machine.
RUN jac install

# The pod gets REDIS_URL from the provisioned secret, so the runtime tries to
# use Redis. Without the client library it fails as
# "Redis connection failed: 'NoneType' object has no attribute 'from_url'" and
# then every OCC-guarded write (CreateTask, MoveTask) dies with a bare
# "list index out of range" that says nothing about Redis. `jac start --scale`
# injects this closure itself; building by hand means adding it by hand.
# --no-save keeps jac.toml untouched.
RUN jac install redis --no-save

EXPOSE 8000
# The base image already sets ENTRYPOINT ["jac"], so CMD must NOT repeat it.
# `CMD ["jac", "start", ...]` runs `jac jac start ...` and dies with the
# confusing "Not a valid file! Only supports `.jac` and `.py`".
CMD ["start", "main.jac"]
