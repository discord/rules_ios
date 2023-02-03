load("@bazel_skylib//lib:paths.bzl", "paths")
load("//rules:library.bzl", "apple_library")

def apple_static_library(name, apple_library = apple_library, public_headers_to_name = {}, private_headers_to_name = {}, **kwargs):
    visibility = kwargs.get("visibility", [])

    kwargs.setdefault("public_headers", []).extend(public_headers_to_name.keys())
    kwargs.setdefault("private_headers", []).extend(private_headers_to_name.keys())
    library = apple_library(name = name, **kwargs)
    platforms = library.platforms if library.platforms else {}

    extra_deps = []

    # Cocoapods uses the `pod_name`
    headers_sandbox_name = name
    if public_headers_to_name:
        public_headers_symlinks_name = "{}_public_headers_symlinks".format(name)
        _headers_symlinks(
            name = public_headers_symlinks_name,
            hdrs = public_headers_to_name,
            headers_sandbox_name = headers_sandbox_name,
            visibility = visibility,
        )
        extra_deps.append(public_headers_symlinks_name)
    if private_headers_to_name:
        private_headers_symlinks_name = "{}_private_headers_symlinks".format(name)

        # Don't include these in the deps by default, can be pulled in if desired.
        _headers_symlinks(
            name = private_headers_symlinks_name,
            hdrs = private_headers_to_name,
            headers_sandbox_name = headers_sandbox_name,
            visibility = visibility,
        )

    native.objc_library(
        name = name,
        deps = library.deps + extra_deps,
        data = [library.data] if library.data else [],
        linkopts = library.linkopts,
        testonly = kwargs.get("testonly", False),
        visibility = visibility,
    )

def _headers_symlinks_impl(ctx):
    if not ctx.attr.hdrs:
        return []

    outputs = []
    public_headrs_dir = None
    for hdr, sub_path in ctx.attr.hdrs.items():
        output = ctx.actions.declare_file(paths.join(ctx.attr.name, sub_path))
        outputs.append(output)
        if public_headrs_dir == None:
            public_headrs_dir = output.path[:-(len(sub_path) + 1)]
        ctx.actions.symlink(output = output, target_file = hdr.files.to_list()[0])

    output_depset = depset(outputs)
    return [
        DefaultInfo(files = output_depset),
        CcInfo(compilation_context = cc_common.create_compilation_context(
            headers = output_depset,
            includes = depset([
                public_headrs_dir,
                paths.join(public_headrs_dir, ctx.attr.headers_sandbox_name),
            ]),
        )),
        apple_common.new_objc_provider(),
    ]

_headers_symlinks = rule(
    implementation = _headers_symlinks_impl,
    attrs = {
        "hdrs": attr.label_keyed_string_dict(allow_files = True),
        "headers_sandbox_name": attr.string(mandatory = True),
    },
)
