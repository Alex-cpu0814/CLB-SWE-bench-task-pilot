# 旧版迁移和历史复测

在当前任务仓库根目录构建三题的评测镜像，再复测 Base、Gold 和三条历史模型补丁。

~~~bash
swebench images build . --namespace swebench -j 1 \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175
python tools/archive/verify_pilot.py --output scratch --run-id clb-pilot
~~~

结果写入 `scratch/clb-pilot-comparison.json`。新一轮复测使用新的 `--run-id`。
中断后可用原 `--run-id` 加 `--resume` 继续。历史候选的来源、镜像版本和补丁哈希见[复测记录](fixtures/provenance.json)。

旧数据导入会复原迁移前的任务目录。如果持有冻结数据，可以在提交 `8dad82e` 的工作树里，使用当时的
`python tools/import_frozen_tasks.py /path/to/CLB-SWE-bench-v1 --check` 核对原始迁移。
[历史导入工具](https://github.com/Alex-cpu0814/CLB-SWE-bench-task-pilot/blob/8dad82e4571f36dd023d046cc2f0bb15af5be50d/tools/import_frozen_tasks.py)
