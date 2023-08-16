load("@bazel_skylib//lib:paths.bzl", "paths")

def _stringify_mapping(headers_mapping):
    """
    Convert a mapping of {Target: string} to a mapping of {string:string}

    - Target is a target pointing to a single source file
    - the value in `headers_mapping` is the path within Headers/PrivateHeaders to use
      for the file.
    """
    ret = {}
    for (t, dest) in headers_mapping.items():
        files = t.files.to_list()
        if len(files) != 1:
            fail("{} should be a single file".format(t))
        f = files[0]
        if not f.is_source:
            fail("{} should be a single source file, not a generated file".format(f))
        ret[f.owner.name] = dest
    return ret

def _get_mapped_path(hdr, headers_mapping):
    """
    Get the relative destination path for a File

    This will return the value of mapping, or the basename of the file if no
    mapping exists or if `hdr` is not a source file.
    """
    if hdr.is_source:
        return headers_mapping.get(hdr.owner.name, hdr.basename)
    else:
        return hdr.basename

def _get_string_mapped_path(hdr, headers_mapping):
    return headers_mapping.get(hdr, paths.basename(hdr))

def _mapped_without_prefix(files, prefix):
    """
    Convert a list of source files to a mapping of those files -> paths with
    `prefix` removed
    """
    ret = {}
    for file in files:
        if file.startswith(prefix):
            ret[file] = file[len(prefix):]
        else:
            fail("File `{}` does not start with prefix `{}`".format(file, prefix))
    return ret

def _glob_and_strip_prefix(src_dirs, suffix = ".h"):
    """
    Takes a list of directories, and converts them to a mapping of src -> dest

    For each src_dir, all files ending in `suffix`, recursively, are remapped.
    The remapping is from the original path to the last component of `src_dir` +
    the remainder of that file's path. The most topologically deep path gets
    precedence in the returned dictionary.

    For example, for ReactCommon,
    `glob_and_strip_prefix(["react", "react/renderer/imagemanager/platform/ios/react"])`

    might return something like:

    {
        ...
        # Matched from src_dir = "react", glob "react/**/*.h"
        "react/debug/flags.h": "react/debug/flags.h",
        ...
        # Matched from src_dir = "react/renderer/imagemanager/platform/ios/react"
        #   glob "react/renderer/imagemanager/platform/ios/react/**/*.h"
        "react/renderer/imagemanager/platform/ios/react/renderer/imagemanager/RCTImageManager.h": "react/renderer/iamgemanager/RCTImageManager.h",
        ...
    }

    This is mostly useful for merging several directories of globs into a single
    mapping for use by `cc_headers_symlinks` in `@rules_ios//:apple_static_library.bzl`
    """
    ret = {}
    for src_dir in sorted(src_dirs):
        top_level = paths.basename(src_dir)
        prefix = paths.dirname(src_dir)
        to_strip = len(prefix) + 1 if prefix else 0
        for file in native.glob(["{}/**/*{}".format(src_dir, suffix)]):
            ret[file] = file[to_strip:]
    return ret

header_paths = struct(
    stringify_mapping = _stringify_mapping,
    get_mapped_path = _get_mapped_path,
    get_string_mapped_path = _get_string_mapped_path,
    mapped_without_prefix = _mapped_without_prefix,
    glob_and_strip_prefix = _glob_and_strip_prefix,
)
