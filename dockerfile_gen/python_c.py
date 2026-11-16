"""Generation settings for the Python–C cohort."""

COHORTS = {"python50"}
PILOT_NORMALIZERS = {
    "scipy__scipy-clb-002": "python /opt/clb-pilot/normalize_results.py pytest",
}


# Default build commands for each upstream project.
BUILD_BY_PROJECT = {
    "astrofrog__fast-histogram": r"""
build_project() {
    python setup.py build_ext --inplace --force
}

""",
    "bcdev__jpy": r"""
build_project() {
    python2.7 setup.py clean build_ext --inplace --force && mkdir -p target/test-classes && javac -d target/test-classes src/main/java/org/jpy/annotations/*.java src/test/java/org/jpy/fixtures/*.java
}

""",
    "cheetahtemplate3__cheetah3": r"""
build_project() {
    python setup.py build_ext --inplace
}

""",
    "ghaering__pysqlite": r"""
build_project() {
    python2.7 setup.py build_ext --force build_py --force
}

""",
    "numpy__numpy": r"""
build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

""",
    "pygame__pygame": r"""
build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"' && cp lib/freesansbold.ttf /testbed/build/local/pygame/freesansbold.ttf
}

""",
    "pygobject__pycairo": r"""
build_project() {
    python setup.py build_ext --inplace --force
}

""",
    "python-pillow__pillow": r"""
build_project() {
    python setup.py build_ext -i --force
}

""",
    "scipy__scipy": r"""
build_project() {
    python3.8 setup.py build_ext -i
}

""",
    "spglib__spglib": r"""
build_project() {
    cmake -S test -B build -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=/opt/googletest && cmake --build build --target test_magnetic_symmetry --parallel 2
}

""",
    "tskit-dev__tskit": r"""
build_project() {
    (cd python && python setup.py build_ext --inplace)
}

""",
    "ultrajson__ultrajson": r"""
build_project() {
    python setup.py build_ext -i --force
}

""",
}


PYGAME_BUILD_WITHOUT_FONT_COPY = r"""
build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"'
}

"""


PYGAME_BUILD_WITH_SRC_FONT = r"""
build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"' && cp src_py/freesansbold.ttf /testbed/build/local/pygame/freesansbold.ttf
}

"""


# Builds that differ from their project's default.
BUILD_OVERRIDES = {
    "numpy__numpy-clb-007": r"""
build_project() {
    python3.8-dbg setup.py build_ext -i
}

""",
    "numpy__numpy-clb-031": r"""
build_project() {
    sed -i '5i from distutils.errors import DistutilsExecError' numpy/distutils/ccompiler.py
    python2.7 setup.py build_ext -i --force
}

""",
    "pygame__pygame-clb-075": PYGAME_BUILD_WITHOUT_FONT_COPY,
    "pygame__pygame-clb-077": PYGAME_BUILD_WITHOUT_FONT_COPY,
    "pygame__pygame-clb-081": PYGAME_BUILD_WITH_SRC_FONT,
    "pygame__pygame-clb-082": PYGAME_BUILD_WITH_SRC_FONT,
    "pygame__pygame-clb-086": PYGAME_BUILD_WITH_SRC_FONT,
    "scipy__scipy-clb-002": r"""
# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py build_ext -i
}

""",
    "scipy__scipy-clb-037": r"""
build_project() {
    python3.8 setup.py build_ext -i || return $?
    # SciPy 0.10 converts Python sources into build/py3k. NumPy 1.17
    # no longer provides the historical lazy package loader.
    sed -i '/from numpy\._import_tools import PackageLoader/,/pkgload(verbose=SCIPY_IMPORT_VERBOSE,postpone=True)/d' \
        /testbed/build/py3k/scipy/__init__.py
}

""",
    "scipy__scipy-clb-044": r"""
build_project() {
    python3.6 setup.py build_ext -i
}

""",
    "scipy__scipy-clb-048": r"""
build_project() {
    touch scipy/signal/sigtoolsmodule.c && CFLAGS="-O0 -g -fsanitize=bounds -fno-sanitize-recover=bounds" LDFLAGS="-fsanitize=bounds" python setup.py build_ext -i
}

""",
}


# Commands executed inside run_project_tests for each instance.
TEST_COMMANDS = {
    "astrofrog__fast-histogram-clb-159": r"""    python /benchmark/pytest_no_dump.py -vv \
        'fast_histogram/tests/test_histogram.py::test_nd_arrays' \
        'fast_histogram/tests/test_histogram.py::test_list' \
        'fast_histogram/tests/test_histogram.py::test_non_contiguous' \
        'fast_histogram/tests/test_histogram.py::test_mixed_strides'
}
""",
    "astrofrog__fast-histogram-clb-160": r"""    python /benchmark/pytest_no_dump.py -vv -p no:warnings --hypothesis-show-statistics \
        'fast_histogram/tests/test_histogram.py::test_1d_compare_with_numpy' \
        'fast_histogram/tests/test_histogram.py::test_2d_compare_with_numpy' \
        'fast_histogram/tests/test_histogram.py::test_nd_arrays'
}
""",
    "bcdev__jpy-clb-176": r"""    python2.7 /benchmark/unittest_native_runner.py \
        'src/test/python/jpy_array_test.py::TestJavaArrays::test_array_int' \
        'src/test/python/jpy_array_test.py::TestJavaArrays::test_array_object' \
        'src/test/python/jpy_array_test.py::TestJavaArrays::test_buffer_int' \
        'src/test/python/jpy_array_test.py::TestJavaArrays::test_array_item_del'
}
""",
    "bcdev__jpy-clb-177": r"""    python2.7 /benchmark/unittest_native_runner.py \
        'src/test/python/jpy_overload_test.py::TestMethodOverloads::test_2ArgOverloadsWithVaryingTypes' \
        'src/test/python/jpy_overload_test.py::TestMethodOverloads::test_nArgOverloads' \
        'src/test/python/jpy_overload_test.py::TestMethodOverloads::test_nArgOverloadsAreFoundInBaseClass' \
        'src/test/python/jpy_overload_test.py::TestStaticMethodOverloads::test_staticMethodIsFoundOverNonStatic'
}
""",
    "cheetahtemplate3__cheetah3-clb-049": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv \
        'Cheetah/Tests/SyntaxAndOutput.py::GetVar::test1' \
        'Cheetah/Tests/SyntaxAndOutput.py::GetVar::test2' \
        'Cheetah/Tests/SyntaxAndOutput.py::GetVar::test6'
}
""",
    "ghaering__pysqlite-clb-156": r"""    python2.7 /benchmark/pysqlite_unittest_nodes.py \
        'lib/test/hooks.py::CollationTests::CheckCreateCollationNotCallable' \
        'lib/test/hooks.py::ProgressTests::CheckProgressHandlerUsed' \
        'lib/test/hooks.py::ProgressTests::CheckCancelOperation' \
        'lib/test/hooks.py::LimitTests::CheckGetLimit' \
        'lib/test/hooks.py::LimitTests::CheckSetLimit'
}
""",
    "numpy__numpy-clb-007": r"""    local leak_status
    local regression_status

    python3.8-dbg -m pytest -vv -R 3:3 \
        numpy/core/tests/test_multiarray.py::TestCreation::test_malloc_fails
    leak_status=$?

    python3.8-dbg -m pytest -vv \
        numpy/core/tests/test_multiarray.py::TestCreation::test_zeros
    regression_status=$?

    if [[ "${leak_status}" -ne 0 || "${regression_status}" -ne 0 ]]; then
        return 1
    fi
    return 0
}
""",
    "numpy__numpy-clb-010": r"""    python3.8-dbg -m pytest -vv \
        numpy/core/tests/test_multiarray.py::TestMethods::test_choose \
        numpy/core/tests/test_multiarray.py::TestMethods::test_round \
        numpy/core/tests/test_multiarray.py::TestMethods::test_trace \
        numpy/core/tests/test_multiarray.py::TestArgmax::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestArgmin::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestTake::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestTake::test_clip \
        numpy/core/tests/test_multiarray.py::TestArgmax::test_output_shape \
        numpy/core/tests/test_multiarray.py::TestMethods::test_trace_subclass
}
""",
    "numpy__numpy-clb-011": r"""    python3.8-dbg -m pytest -vv \
        numpy/core/tests/test_multiarray.py::TestMethods::test_searchsorted \
        numpy/core/tests/test_multiarray.py::TestMethods::test_searchsorted_unicode \
        numpy/core/tests/test_multiarray.py::TestMethods::test_searchsorted_with_sorter
}
""",
    "numpy__numpy-clb-013": r"""    local rc=0
    python3.8-dbg -m pytest -vv \
        numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_big_indices \
        numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_dtypes \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_empty_array_ravel[clip]' || rc=$?
    python3.8-dbg -m pytest -vv \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_empty_array_ravel[wrap]' || rc=$?
    return "$rc"
}
""",
    "numpy__numpy-clb-014": r"""    python3.8-dbg -m pytest -vv \
        'numpy/core/tests/test_dtype.py::TestRecord::test_partial_dict' \
        'numpy/core/tests/test_dtype.py::TestSubarray::test_single_subarray' \
        'numpy/core/tests/test_dtype.py::TestRecord::test_fieldless_views'
}
""",
    "numpy__numpy-clb-015": r"""    python3.8-dbg -m pytest -vv \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_invalid_sequence' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_zerolen_custom_strides' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_zerolen_custom_strides_2d'
}
""",
    "numpy__numpy-clb-022": r"""    python3.8-dbg -m pytest -vv -o markers=slow \
        'numpy/core/tests/test_multiarray.py::test_interface_no_shape' \
        'numpy/core/tests/test_multiarray.py::test_array_interface_itemsize' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val6-iface6-ValueError]' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val8-iface8-ValueError]' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val9-iface9-TypeError]'
}
""",
    "numpy__numpy-clb-023": r"""    python3.8-dbg -m pytest -vv -o markers=slow \
        'numpy/core/tests/test_multiarray.py::TestWritebackIfCopy::test_put_noncontiguous' \
        'numpy/core/tests/test_multiarray.py::TestWritebackIfCopy::test_putmask_noncontiguous' \
        'numpy/core/tests/test_multiarray.py::TestWritebackIfCopy::test_insert_noncontiguous'
}
""",
    "numpy__numpy-clb-027": r"""    python3.8-dbg -m pytest -vv -o markers=slow \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_big_indices' \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_dtypes' \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_empty_indices'
}
""",
    "numpy__numpy-clb-031": r"""    python2.7 -m nose -v \
        'numpy/core/tests/test_multiarray.py:TestChoose.test_basic' \
        'numpy/core/tests/test_multiarray.py:TestChoose.test_broadcast1' \
        'numpy/core/tests/test_multiarray.py:TestChoose.test_broadcast2'
}
""",
    "pygame__pygame-clb-075": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/event_test.py::EventModuleTest::test_post_large_user_event' \
        'test/event_test.py::EventModuleTest::test_get_type' \
        'test/event_test.py::EventModuleTest::test_post_blocked' \
        'test/time_test.py::TimeModuleTest::test_set_timer'
}
""",
    "pygame__pygame-clb-077": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/draw_test.py::DrawRectTest::test_rect__fill' \
        'test/draw_test.py::DrawRectTest::test_rect__one_pixel_lines' \
        'test/draw_test.py::DrawRectTest::test_rect__args_without_width' \
        'test/draw_test.py::DrawRectTest::test_rect__draw_line_width'
}
""",
    "pygame__pygame-clb-081": r"""    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_size' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_scalable' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_fixed_width' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_565'
}
""",
    "pygame__pygame-clb-082": r"""    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/event_test.py::EventModuleTest::test_get' \
        'test/event_test.py::EventModuleTest::test_peek' \
        'test/event_test.py::EventModuleTest::test_get_type' \
        'test/event_test.py::EventModuleTest::test_peek_empty'
}
""",
    "pygame__pygame-clb-086": r"""    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/draw_test.py::DrawPolygonTest::test_draw_square' \
        'test/draw_test.py::DrawPolygonTest::test_draw_diamond' \
        'test/draw_test.py::DrawPolygonTest::test_draw_symetric_cross' \
        'test/draw_test.py::DrawPolygonTest::test_illumine_shape'
}
""",
    "pygame__pygame-clb-088": r"""    python /benchmark/legacy_unittest088.py \
        'test/surface_test.py::SurfaceTypeTest::test_copy' \
        'test/surface_test.py::SurfaceTypeTest::test_get_bytesize' \
        'test/surface_test.py::SurfaceTypeTest::test_get_rect' \
        'test/surface_test.py::SurfaceTypeTest::test_get_bounding_rect'
}
""",
    "pygame__pygame-clb-090": r"""    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/legacy_unittest090.py \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_get_rect' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_style' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_render_mono' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_242'
}
""",
    "pygame__pygame-clb-091": r"""    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/legacy_unittest091.py \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_get_rect' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_render_mono' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_242' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_243'
}
""",
    "pygame__pygame-clb-094": r"""    python /benchmark/legacy_unittest094.py \
        'test/surface_test.py::SurfaceTypeTest::test_copy' \
        'test/surface_test.py::SurfaceTypeTest::test_get_bytesize' \
        'test/surface_test.py::SurfaceTypeTest::test_get_rect' \
        'test/surface_test.py::SurfaceBlendTest::test_blit_blend_big_rect'
}
""",
    "pygobject__pycairo-clb-137": r"""    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_surface.py::test_surface_get_device_scale' \
        'tests/test_surface.py::test_surface_get_content' \
        'tests/test_surface.py::test_surface_get_format' \
        'tests/test_surface.py::test_surface_set_device_scale'
}
""",
    "pygobject__pycairo-clb-138": r"""    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_pattern.py::test_raster_source' \
        'tests/test_pattern.py::test_cmp_hash' \
        'tests/test_pattern.py::test_get_extend' \
        'tests/test_pattern.py::test_get_filter'
}
""",
    "pygobject__pycairo-clb-139": r"""    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_device.py::test_get_device' \
        'tests/test_surface.py::test_script_surface' \
        'tests/test_surface.py::test_script_surface_create_for_target' \
        'tests/test_surface.py::test_script_device_device_ref'
}
""",
    "pygobject__pycairo-clb-141": r"""    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_api.py::test_context' \
        'tests/test_api.py::test_error' \
        'tests/test_api.py::test_pattern' \
        'tests/test_api.py::test_matrix'
}
""",
    "pygobject__pycairo-clb-142": r"""    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_surface.py::test_surface_get_content' \
        'tests/test_surface.py::test_surface_get_format' \
        'tests/test_surface.py::test_image_surface_png_obj_roundtrip' \
        'tests/test_surface.py::test_image_surface_get_data_refcount'
}
""",
    "python-pillow__pillow-clb-053": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_imagedraw.py::test_sanity' \
        'Tests/test_imagefont.py::test_font_properties[Layout.BASIC]' \
        'Tests/test_imagedraw.py::test_point_I16' \
        'Tests/test_imagefont.py::test_I16[Layout.BASIC]'
}
""",
    "python-pillow__pillow-clb-054": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_box_blur.py::test_radius_0' \
        'Tests/test_box_blur.py::test_radius_1' \
        'Tests/test_image_filter.py::test_invalid_box_blur_filter'
}
""",
    "python-pillow__pillow-clb-056": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_image.py::TestImage::test_fp_name' \
        'Tests/test_image.py::TestImage::test_tempfile' \
        'Tests/test_image.py::TestImage::test_pathlib'
}
""",
    "python-pillow__pillow-clb-057": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_file_psd.py::test_sanity' \
        'Tests/test_file_psd.py::test_eoferror' \
        'Tests/test_file_psd.py::test_n_frames'
}
""",
    "python-pillow__pillow-clb-058": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_file_jpeg.py::TestFileJpeg::test_sanity' \
        'Tests/test_file_jpeg.py::TestFileJpeg::test_cmyk' \
        'Tests/test_file_jpeg.py::TestFileJpeg::test_adobe_transform'
}
""",
    "python-pillow__pillow-clb-060": r"""    python /benchmark/pytest_case060_isolated.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_image.py::TestImage::test_linear_gradient_wrong_mode' \
        'Tests/test_image.py::TestImage::test_radial_gradient_wrong_mode' \
        'Tests/test_image.py::TestImage::test_linear_gradient' \
        'Tests/test_image.py::TestImage::test_radial_gradient'
}
""",
    "python-pillow__pillow-clb-066": r"""    python /benchmark/unittest_case066_isolated.py \
        'Tests/test_imagefont.py::TestImageFont::test_default_font' \
        'Tests/test_file_png.py::TestFilePng::test_sanity' \
        'Tests/test_font_leaks.py::TestTTypeFontLeak::test_leak' \
        'Tests/test_font_leaks.py::TestDefaultFontLeak::test_leak'
}
""",
    "python-pillow__pillow-clb-068": r"""    python /benchmark/tester_case068_isolated.py \
        'Tests/test_image_convert.py::test_default' \
        'Tests/test_image_convert.py::test_8bit' \
        'Tests/test_image_quantize.py::test_octree_quantize' \
        'Tests/test_image_convert.py::test_rgba_p' \
        'Tests/test_image_convert.py::test_trns_p' \
        'Tests/test_image_convert.py::test_trns_l' \
        'Tests/test_image_convert.py::test_trns_RGB' \
        'Tests/test_image_quantize.py::test_rgba_quantize'
}
""",
    "scipy__scipy-clb-002": r"""    python -m pytest -vv -W ignore::DeprecationWarning \
        scipy/ndimage/tests/test_interpolation.py
}
""",
    "scipy__scipy-clb-034": r"""    python3.8 -m pytest -vv \
        'scipy/integrate/tests/test_integrate.py::test_odeint_trivial_time' \
        'scipy/integrate/tests/test_integrate.py::test_odeint_bad_shapes' \
        'scipy/integrate/tests/test_integrate.py::test_repeated_t_values'
}
""",
    "scipy__scipy-clb-037": r"""    cd /testbed/build/py3k || return $?
    python3.8 -m pytest -vv \
        'scipy/ndimage/tests/test_regression.py::test_byte_order_median' \
        'scipy/ndimage/tests/test_regression.py::test_zoom_output_shape' \
        'scipy/ndimage/tests/test_regression.py::test_ticket_742'
}
""",
    "scipy__scipy-clb-041": r"""    python3.8 -m pytest -c /dev/null -vv \
        'scipy/interpolate/tests/test_fitpack.py::test_dblint' \
        'scipy/interpolate/tests/test_fitpack.py::test_splev_der_k' \
        'scipy/interpolate/tests/test_fitpack.py::test_splprep_segfault'
}
""",
    "scipy__scipy-clb-042": r"""    python3.8 -m pytest -c /dev/null -vv \
        'scipy/signal/tests/test_bsplines.py::TestBSplines::test_spline_filter' \
        'scipy/signal/tests/test_bsplines.py::TestBSplines::test_bspline' \
        'scipy/signal/tests/test_bsplines.py::test_sepfir2d_invalid_filter'
}
""",
    "scipy__scipy-clb-044": r"""    python3.6 -m pytest -c /dev/null -vv \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates01' \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates02' \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates_large_data'
}
""",
    "scipy__scipy-clb-048": r"""    UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 python /benchmark/pytest_case048_isolated.py \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_basic' \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_none' \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_invalid_dtypes[float16]'
}
""",
    "spglib__spglib-clb-174": r"""    python /benchmark/native_gtest_runner.py --binary /testbed/build/test_magnetic_symmetry \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_symmetry_from_database' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_spacegroup_type' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_dataset_type4' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_symmetry_with_tensors_rough_mag_symprec'
}
""",
    "spglib__spglib-clb-175": r"""    python /benchmark/native_gtest_runner.py --binary /testbed/build/test_magnetic_symmetry \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_symmetry_from_database' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_spacegroup_type' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_dataset_type4' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_symmetry_with_tensors_rough_symprec'
}
""",
    "tskit-dev__tskit-clb-046": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv \
        'python/tests/test_highlevel.py::TestTree::test_newick' \
        'python/tests/test_lowlevel.py::TestTree::test_newick_precision' \
        'python/tests/test_highlevel.py::TestTree::test_newick_large_times' \
        'python/tests/test_lowlevel.py::TestTree::test_newick_interface'
}
""",
    "ultrajson__ultrajson-clb-070": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'tests/test_ujson.py::test_encode_dict_conversion' \
        'tests/test_ujson.py::test_encode_list_conversion' \
        'tests/test_ujson.py::test_decode_from_unicode' \
        'tests/test_ujson.py::test_encode_indent'
}
""",
    "ultrajson__ultrajson-clb-071": r"""    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'tests/test_ujson.py::test_encode_dict_conversion' \
        'tests/test_ujson.py::test_encode_list_conversion' \
        'tests/test_ujson.py::test_decode_from_unicode' \
        'tests/test_ujson.py::test_encode_indent[{\n    "obj": 31337\n}]' \
        'tests/test_ujson.py::test_encode_indent[{}]' \
        'tests/test_ujson.py::test_encode_indent[[]]' \
        'tests/test_ujson.py::test_encode_indent[{\n    "a": {}\n}]' \
        'tests/test_ujson.py::test_encode_indent[[\n    []\n]]'
}
""",
}


# Files shared by every task of a project.
PROJECT_FIXTURES = {
    "astrofrog__fast-histogram": (
        "astrofrog__fast-histogram/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "bcdev__jpy": (
        "bcdev__jpy/format_test_log.py",
        "bcdev__jpy/unittest_native_runner.py",
    ),
    "cheetahtemplate3__cheetah3": (
        "cheetahtemplate3__cheetah3/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "ghaering__pysqlite": (
        "ghaering__pysqlite/format_test_log.py",
        "ghaering__pysqlite/pysqlite_unittest_nodes.py",
    ),
    "numpy__numpy": ("numpy__numpy/format_test_log.py",),
    "pygobject__pycairo": (
        "pygobject__pycairo/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "spglib__spglib": (
        "common/pygame__pygame-clb-088/format_test_log.py",
        "spglib__spglib/native_gtest_runner.py",
        "spglib__spglib/native_no_core.c",
    ),
    "tskit-dev__tskit": (
        "tskit-dev__tskit/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "ultrajson__ultrajson": ("common/pytest_no_dump.py",),
}


# Additional files required by specific tasks.
INSTANCE_FIXTURES = {
    "pygame__pygame-clb-075": (
        "pygame__pygame/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "pygame__pygame-clb-077": (
        "pygame__pygame/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "pygame__pygame-clb-081": (
        "pygame__pygame/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "pygame__pygame-clb-082": (
        "pygame__pygame/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "pygame__pygame-clb-086": (
        "pygame__pygame/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "pygame__pygame-clb-088": (
        "common/pygame__pygame-clb-088/format_test_log.py",
        "pygame__pygame/legacy_unittest088.py",
    ),
    "pygame__pygame-clb-090": (
        "common/pygame__pygame-clb-088/format_test_log.py",
        "pygame__pygame/legacy_unittest090.py",
    ),
    "pygame__pygame-clb-091": (
        "common/pygame__pygame-clb-088/format_test_log.py",
        "pygame__pygame/legacy_unittest091.py",
    ),
    "pygame__pygame-clb-094": (
        "common/pygame__pygame-clb-088/format_test_log.py",
        "pygame__pygame/legacy_unittest094.py",
    ),
    "python-pillow__pillow-clb-053": (
        "python-pillow__pillow/053/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-054": (
        "python-pillow__pillow/053/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-056": (
        "python-pillow__pillow/053/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-057": (
        "python-pillow__pillow/053/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-058": (
        "python-pillow__pillow/053/format_test_log.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-060": (
        "python-pillow__pillow/060/format_test_log.py",
        "python-pillow__pillow/pytest_case060_isolated.py",
        "common/pytest_no_dump.py",
    ),
    "python-pillow__pillow-clb-066": (
        "python-pillow__pillow/053/format_test_log.py",
        "python-pillow__pillow/unittest_case066_isolated.py",
    ),
    "python-pillow__pillow-clb-068": (
        "python-pillow__pillow/053/format_test_log.py",
        "python-pillow__pillow/tester_case068_isolated.py",
    ),
    "scipy__scipy-clb-002": ("common/normalize_results.py",),
    "scipy__scipy-clb-034": ("scipy__scipy/format_test_log.py",),
    "scipy__scipy-clb-037": ("scipy__scipy/format_test_log.py",),
    "scipy__scipy-clb-041": ("scipy__scipy/format_test_log.py",),
    "scipy__scipy-clb-042": ("scipy__scipy/format_test_log.py",),
    "scipy__scipy-clb-044": ("scipy__scipy/format_test_log.py",),
    "scipy__scipy-clb-048": (
        "scipy__scipy/format_test_log.py",
        "scipy__scipy/pytest_case048_isolated.py",
        "common/pytest_no_dump.py",
    ),
    "ultrajson__ultrajson-clb-070": ("ultrajson__ultrajson/070/format_test_log.py",),
    "ultrajson__ultrajson-clb-071": ("ultrajson__ultrajson/071/format_test_log.py",),
}
