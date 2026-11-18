* ==========================================================================================
* run_all.do —— 按顺序运行全部步骤
*
* 用法：Stata 里先 cd 到 full_panel 文件夹，再运行：do code/run_all.do
*
*   01_clean_entities.do   FactSet 公司信息、换 ID 对照表（与另外两个文件夹相同）
*   02_clean_firms.do      加征关税行业、ST、CSMAR、Worldscope 2017 年财务指标（与另外两个文件夹相同）
*   03_full_panel.do       供应链 + 合作关系 -> 完整面板 full_panel.dta
*   04_export.do           导出 full_panel.csv 和变量说明表 full_panel_codebook.csv
*   05_check_samples.do    核对完整面板与另外两个文件夹的样本逐行一致（需要它们的 data/clean，没有就跳过）
*   Parquet 版本另外用 Python 生成：python3 code/04b_to_parquet.py data/clean/full_panel.dta data/clean/full_panel.parquet
*
* 已有 01、02 生成的 5 个中间文件时（Drive 上 replication_jjyj2024 文件夹里有），放进 data/clean/，
* 把下面的 local clean 改成 0，就从 03 开始跑（03 仍要原始的 relationship.csv）。
* ==========================================================================================
local clean 1

if `clean' {
    do "code/01_clean_entities.do"
    do "code/02_clean_firms.do"
}
do "code/03_full_panel.do"
do "code/04_export.do"

capture confirm file "../replication_jjyj2024/data/clean/analysis_sample.dta"
local miss1 = _rc
capture confirm file "../partnership_break/data/clean/analysis_K.dta"
local miss2 = _rc
if !`miss1' & !`miss2' do "code/05_check_samples.do"
else di as txt "（没有另外两个文件夹的清洗数据，跳过 05_check_samples.do）"
