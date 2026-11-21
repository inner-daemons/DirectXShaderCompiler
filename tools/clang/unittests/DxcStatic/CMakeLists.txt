# Tests that link dxcompiler_static directly, with no dlopen/LoadLibrary of
# dxcompiler.

set(LLVM_LINK_COMPONENTS
  Support
  )

add_clang_unittest(DxcStaticTests
  DxcStaticTest.cpp
  )
target_link_libraries(DxcStaticTests
  dxcompiler_static
  )

# The same tests, linked against the merged dxcompiler_static_bundle archive
# instead of the CMake target, to check that the bundle is self-contained. The
# bundle is linked in the top-level CMakeLists.txt, once it exists.
add_clang_unittest(DxcStaticBundleTests
  DxcStaticTest.cpp
  )
