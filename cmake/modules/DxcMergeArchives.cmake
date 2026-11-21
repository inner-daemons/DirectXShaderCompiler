# cmake -DTOOL=<ar|libtool|lib> -DAR=<archiver> -DOUTPUT=<archive>
#       -DINPUTS=<file listing input archives> -P DxcMergeArchives.cmake
#
# Merges static libraries into one archive.

file(STRINGS "${INPUTS}" inputs)
file(REMOVE "${OUTPUT}")

if(TOOL STREQUAL "ar")
  # GNU ar and llvm-ar both accept MRI scripts, which merge archives without
  # extracting members (members with the same name would collide otherwise).
  set(script "CREATE ${OUTPUT}\n")
  foreach(input ${inputs})
    string(APPEND script "ADDLIB ${input}\n")
  endforeach()
  string(APPEND script "SAVE\nEND\n")
  file(WRITE "${OUTPUT}.mri" "${script}")
  execute_process(COMMAND "${AR}" -M INPUT_FILE "${OUTPUT}.mri"
                  RESULT_VARIABLE result)
elseif(TOOL STREQUAL "libtool")
  execute_process(COMMAND libtool -static -no_warning_for_no_symbols
                          -o "${OUTPUT}" ${inputs}
                  RESULT_VARIABLE result)
else()
  if(NOT AR)
    set(AR lib)
  endif()
  execute_process(COMMAND "${AR}" /NOLOGO "/OUT:${OUTPUT}" ${inputs}
                  RESULT_VARIABLE result)
endif()

if(NOT result EQUAL 0)
  file(REMOVE "${OUTPUT}")
  message(FATAL_ERROR "Failed to create ${OUTPUT}")
endif()
