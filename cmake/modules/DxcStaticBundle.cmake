# dxc_add_static_bundle(<bundle> <static library target>)
#
# Merges a static library and every static library it transitively links into
# one archive, so it can be used without CMake or the DXC build tree. Call it
# after all targets exist (the end of the top-level CMakeLists.txt). The system
# libraries the bundle still needs are written one per line to <bundle>.libs,
# which is installed next to it. Sets <bundle>_FILE and <bundle>_SYSTEM_LIBS in
# the caller's scope.

function(dxc_static_deps target out_libs out_system)
  set(visited)
  set(system)
  set(queue ${target})
  while(queue)
    list(GET queue 0 t)
    list(REMOVE_AT queue 0)
    if(t IN_LIST visited)
      continue()
    endif()
    list(APPEND visited ${t})
    foreach(prop LINK_LIBRARIES INTERFACE_LINK_LIBRARIES)
      get_target_property(deps ${t} ${prop})
      if(NOT deps)
        continue()
      endif()
      foreach(dep ${deps})
        string(REGEX REPLACE "^\\$<LINK_ONLY:(.*)>$" "\\1" dep "${dep}")
        if(TARGET ${dep})
          get_target_property(type ${dep} TYPE)
          if(type STREQUAL "STATIC_LIBRARY")
            list(APPEND queue ${dep})
          elseif(NOT type STREQUAL "INTERFACE_LIBRARY")
            message(FATAL_ERROR "${target} links non-static target ${dep}")
          endif()
        elseif(dep MATCHES "^\\$<")
          message(FATAL_ERROR "${target}: unhandled link item ${dep}")
        elseif(NOT dep IN_LIST system)
          list(APPEND system ${dep})
        endif()
      endforeach()
    endforeach()
  endwhile()
  set(${out_libs} ${visited} PARENT_SCOPE)
  set(${out_system} ${system} PARENT_SCOPE)
endfunction()

function(dxc_add_static_bundle bundle target)
  dxc_static_deps(${target} libs system_libs)

  set(file_name
      "${CMAKE_STATIC_LIBRARY_PREFIX}${bundle}${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(output "${LLVM_LIBRARY_OUTPUT_INTDIR}/${file_name}")
  set(inputs)
  foreach(lib ${libs})
    list(APPEND inputs "$<TARGET_FILE:${lib}>")
  endforeach()
  string(REPLACE ";" "\n" inputs "${inputs}")
  set(inputs_file "${CMAKE_BINARY_DIR}/${bundle}-$<CONFIG>.inputs")
  file(GENERATE OUTPUT "${inputs_file}" CONTENT "${inputs}\n")
  set(libs_file "${CMAKE_BINARY_DIR}/${bundle}.libs")
  string(REPLACE ";" "\n" system_text "${system_libs}")
  file(WRITE "${libs_file}" "${system_text}\n")

  if(MSVC)
    set(tool lib)
  elseif(APPLE)
    set(tool libtool)
  else()
    set(tool ar)
  endif()
  set(merge_script "${LLVM_MAIN_SRC_DIR}/cmake/modules/DxcMergeArchives.cmake")
  add_custom_command(OUTPUT "${output}"
    COMMAND "${CMAKE_COMMAND}" -DTOOL=${tool} "-DAR=${CMAKE_AR}"
            "-DOUTPUT=${output}" "-DINPUTS=${inputs_file}"
            -P "${merge_script}"
    DEPENDS ${libs} "${merge_script}"
    COMMENT "Bundling ${target} and its static dependencies into ${file_name}"
    VERBATIM)
  add_custom_target(${bundle} ALL DEPENDS "${output}")
  set_target_properties(${bundle} PROPERTIES FOLDER "Libraries")

  install(FILES "$<TARGET_FILE_DIR:${target}>/${file_name}" "${libs_file}"
    DESTINATION lib${LLVM_LIBDIR_SUFFIX}
    COMPONENT ${bundle})
  add_custom_target(install-${bundle}
    DEPENDS ${bundle}
    COMMAND "${CMAKE_COMMAND}"
            -DCMAKE_INSTALL_COMPONENT=${bundle}
            -P "${CMAKE_BINARY_DIR}/cmake_install.cmake")

  set(${bundle}_FILE "${output}" PARENT_SCOPE)
  set(${bundle}_SYSTEM_LIBS ${system_libs} PARENT_SCOPE)
endfunction()
