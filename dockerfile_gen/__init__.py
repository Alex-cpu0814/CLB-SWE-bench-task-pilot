"""Generate Dockerfile and eval.sh for CLB tasks."""

import re

from . import java_c, python_c
from .constants import CONTAINER_WORKDIR
from .templates import EVAL_SCRIPT, PILOT_EVAL_SCRIPT
from .utils import prepare_test_patch, validate_base_image as validate_base_image


def render_files(instance_id, cohort, base_commit, base_image, test_patch):
    """Render both task files from metadata, the pinned image, and the test patch."""
    validate_base_image(instance_id, base_image)
    if not isinstance(base_commit, str) or not re.fullmatch("[0-9a-f]{40}", base_commit):
        raise ValueError(f"Invalid Base commit for {instance_id}")
    test = prepare_test_patch(instance_id, test_patch)

    if cohort in python_c.COHORTS:
        pilot_normalizer = python_c.PILOT_NORMALIZERS.get(instance_id)
    elif cohort in java_c.COHORTS:
        pilot_normalizer = java_c.PILOT_NORMALIZERS.get(instance_id)
    else:
        raise ValueError(f"Unknown cohort for {instance_id}: {cohort}")

    if pilot_normalizer:
        dockerfile = f"FROM {base_image}\nCOPY runtime/ /opt/clb-pilot/\n"
        script = PILOT_EVAL_SCRIPT.replace("@NORMALIZE@", pilot_normalizer)
    else:
        dockerfile = f"FROM {base_image}\nCOPY runtime/ /benchmark/\n"
        script = EVAL_SCRIPT.replace("@MOUNTS@", java_c.EVAL_SETUP.get(instance_id, ""))
        if cohort in java_c.COHORTS:
            dockerfile += java_c.DOCKER_SETUP.get(instance_id, "")
            excluded = " -e bin" if instance_id in java_c.PRESERVE_BIN else ""
            dockerfile += f"RUN git -C {CONTAINER_WORKDIR} clean -fdx{excluded}\n"

    script = script.replace("@BASE@", base_commit).replace("@TEST@", test)
    return {"Dockerfile": dockerfile.encode("utf-8"), "eval.sh": script.encode("utf-8")}
