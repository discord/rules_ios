load("@bazel_skylib//lib:paths.bzl", "paths")
load("//rules:library.bzl", "apple_library")

def apple_static_library(
        name,
        apple_library = apple_library,
        public_headers = [],
        public_headers_to_name = {},
        deps = [],
        visibility = [],
        testonly = False,
        system_module = True,
        **kwargs):

    """
    A thin wrapper around `apple_library` that exposes a single target to depend on
    and allows additionally exposing renamed headers.

    public_headers_to_name is a dictionary that maps input files to their output
    location within the link tree. This link tree then is added as a dep to the
    final library. This allows us to effectively "move" headers and #include them
    at whatever path we want.

    Every other attribute is passed through to applie_library/objc_library as is
    from **kwargs.

    Examples:
        In the case below, we declare "include/fmt/chorno.h" as a public header,
        but we remap it so that '#include <fmt/chrono.h>' works.

        ```
		apple_static_library(
			name = "Texture",
			srcs = glob([
				"Source/**/*.h",
				"Source/**/*.mm",
				"Source/TextKit/*.h",
			]),
			module_name = "AsyncDisplayKit",
			platforms = {"ios": "9.0"},
			public_headers = [
				"Source/ASBlockTypes.h",
				"Source/ASButtonNode+Private.h",
				"Source/ASButtonNode+Yoga.h",
				"Source/ASButtonNode.h",
				"Source/ASCellNode.h",
				"Source/ASCollectionNode+Beta.h",
				"Source/ASCollectionNode.h",
				"Source/ASCollections.h",
				"Source/ASCollectionView.h",
				"Source/ASCollectionViewLayoutFacilitatorProtocol.h",
				"Source/ASCollectionViewProtocols.h",
				"Source/ASConfiguration.h",
				"Source/ASConfigurationDelegate.h",
				"Source/ASConfigurationInternal.h",
				"Source/ASContextTransitioning.h",
				"Source/ASControlNode+Subclasses.h",
				"Source/ASControlNode.h",
				"Source/ASDisplayNode+Beta.h",
				"Source/ASDisplayNode+Convenience.h",
				"Source/ASDisplayNode+InterfaceState.h",
				"Source/ASDisplayNode+LayoutSpec.h",
				"Source/ASDisplayNode+Subclasses.h",
				"Source/ASDisplayNode+Yoga.h",
				...
				"Source/Details/ASAbstractLayoutController.h",
				"Source/Details/ASBasicImageDownloader.h",
				"Source/Details/ASBatchContext.h",
				...
				"Source/Debug/AsyncDisplayKit+Tips.h",
				"Source/TextKit/ASTextNodeTypes.h",
				"Source/TextKit/ASTextKitComponents.h",
			],
			public_headers_to_name = {
				"Source/ASBlockTypes.h": "Texture/AsyncDisplayKit/ASBlockTypes.h",
				"Source/ASButtonNode+Private.h": "Texture/AsyncDisplayKit/ASButtonNode+Private.h",
				"Source/ASButtonNode+Yoga.h": "Texture/AsyncDisplayKit/ASButtonNode+Yoga.h",
				...
				"Source/Details/ASAbstractLayoutController.h": "Texture/AsyncDisplayKit/ASAbstractLayoutController.h",
				"Source/Details/ASBasicImageDownloader.h": "Texture/AsyncDisplayKit/ASBasicImageDownloader.h",
				"Source/Details/ASBatchContext.h": "Texture/AsyncDisplayKit/ASBatchContext.h",
				...
				"Source/Debug/AsyncDisplayKit+Tips.h": "Texture/AsyncDisplayKit/AsyncDisplayKit+Tips.h",
				"Source/TextKit/ASTextNodeTypes.h": "Texture/AsyncDisplayKit/ASTextNodeTypes.h",
				"Source/TextKit/ASTextKitComponents.h": "Texture/AsyncDisplayKit/ASTextKitComponents.h",
			},
			sdk_dylibs = ["c++"],
			sdk_frameworks = [
				"AVFoundation",
				"AssetsLibrary",
				"CoreLocation",
				"CoreMedia",
				"MapKit",
				"Photos",
			],
			visibility = ["//visibility:public"],
			xcconfig = {
				"CLANG_CXX_LANGUAGE_STANDARD": "c++11",
				"CLANG_CXX_LIBRARY": "libc++",
				"GCC_PREPROCESSOR_DEFINITIONS": [
					"AS_USE_ASSETS_LIBRARY=1",
					"AS_USE_MAPKIT=1",
					"AS_USE_PHOTOS=1",
					"AS_USE_VIDEO=1",
				],
			},
			deps = ["@PINRemoteImage"],
		)
        ```
    """

    extra_deps = []

    # TODO(nmj): We'll likely need to add a way to set up a private headers link tree
    #            that others can include as a dependency too. This is just a thing
    #            that some Pods do.
    if public_headers_to_name:
        public_headers_symlinks_name = "{}_public_headers_symlinks".format(name)
        _headers_symlinks(
            name = public_headers_symlinks_name,
            hdrs = public_headers_to_name,
            system_module = system_module,
            visibility = visibility,
        )
        extra_deps.append(public_headers_symlinks_name)

    library = apple_library(
        name = name,
        public_headers = public_headers,
        visibility=visibility,
        testonly=testonly,
        deps = deps + extra_deps,
        system_module = system_module,
        **kwargs
    )

    native.objc_library(
        name = name,
        deps = library.deps,
        data = [library.data] if library.data else [],
        linkopts = library.linkopts,
        testonly = kwargs.get("testonly", False),
        visibility = visibility,
    )

def _headers_symlinks_impl(ctx):
    if not ctx.attr.hdrs:
        return []

    outputs = []
    public_headers_dir = None
    for hdr, sub_path in ctx.attr.hdrs.items():
        output = ctx.actions.declare_file(paths.join(ctx.attr.name, sub_path))
        outputs.append(output)
        if public_headers_dir == None:
            public_headers_dir = output.path[:-(len(sub_path) + 1)]
        ctx.actions.symlink(output = output, target_file = hdr.files.to_list()[0])

    output_depset = depset(outputs)
    if ctx.attr.system_module:
        compilation_context = cc_common.create_compilation_context(
            headers = output_depset,
            system_includes = depset([
                public_headers_dir,
            ]),
        )
    else:
        compilation_context = cc_common.create_compilation_context(
            headers = output_depset,
            includes = depset([
                public_headers_dir,
            ]),
        )
    return [
        DefaultInfo(files = output_depset),
        CcInfo(compilation_context = compilation_context),
        apple_common.new_objc_provider(),
    ]

_headers_symlinks = rule(
    implementation = _headers_symlinks_impl,
    doc = "Rule that actually creates symlink trees for header remapping",
    attrs = {
        "hdrs": attr.label_keyed_string_dict(
            allow_files = True,
            doc = "Mapping of source file paths to relative path where the file should life in the link tree"
        ),
        "system_module": attr.bool(
            default = True,
            doc = "Whether the symlink headers dir should be exported as a system_include"
        ),
    },
)
