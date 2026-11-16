"""Generate Dockerfile and eval.sh for CLB tasks."""

import re
from importlib.resources import files

from . import java_c, python_c
from .constants import CONTAINER_WORKDIR
from .templates import EVAL_SCRIPT, PILOT_EVAL_SCRIPT
from .utils import copy_inline, prepare_test_patch, validate_base_image as validate_base_image


def render_files(instance_id, cohort, base_commit, base_image, test_patch):
    """Render both task files from metadata, the pinned image, and the test patch."""
    validate_base_image(instance_id, base_image)
    if not isinstance(base_commit, str) or not re.fullmatch("[0-9a-f]{40}", base_commit):
        raise ValueError(f"Invalid Base commit for {instance_id}")
    test = prepare_test_patch(instance_id, test_patch)

    if cohort in python_c.COHORTS:
        language = python_c
    elif cohort in java_c.COHORTS:
        language = java_c
    else:
        raise ValueError(f"Unknown cohort for {instance_id}: {cohort}")

    pilot_normalizer = language.PILOT_NORMALIZERS.get(instance_id)
    if pilot_normalizer:
        asset_dir = "/opt/clb-pilot"
        script = PILOT_EVAL_SCRIPT.replace("@NORMALIZE@", pilot_normalizer)
    else:
        asset_dir = "/benchmark"
        script = EVAL_SCRIPT.replace("@MOUNTS@", java_c.EVAL_SETUP.get(instance_id, ""))

    project = instance_id.rsplit("-clb-", 1)[0]
    build = language.BUILD_OVERRIDES.get(instance_id, language.BUILD_BY_PROJECT[project])
    test_commands = language.TEST_COMMANDS[instance_id]
    adapter = f"#!/usr/bin/env bash\n{build}run_project_tests() {{\n{test_commands}"
    dockerfile = f"FROM {base_image}\n"
    dockerfile += copy_inline(adapter, f"{asset_dir}/case_adapter.sh")

    fixtures = files(__package__) / "fixtures"
    sources = language.PROJECT_FIXTURES.get(project, ()) + language.INSTANCE_FIXTURES.get(instance_id, ())
    for source in sorted(sources, key=lambda path: path.rsplit("/", 1)[-1]):
        fixture = fixtures.joinpath(*source.split("/"))
        dockerfile += copy_inline(fixture.read_text(encoding="utf-8"), f"{asset_dir}/{fixture.name}")

    if language is java_c and not pilot_normalizer:
        dockerfile += java_c.DOCKER_SETUP.get(instance_id, "")
        excluded = " -e bin" if instance_id in java_c.PRESERVE_BIN else ""
        dockerfile += f"RUN git -C {CONTAINER_WORKDIR} clean -fdx{excluded}\n"

    script = script.replace("@BASE@", base_commit).replace("@TEST@", test)
    return {"Dockerfile": dockerfile.encode("utf-8"), "eval.sh": script.encode("utf-8")}
