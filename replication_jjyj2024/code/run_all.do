* ==========================================================================================
* run_all.do —— 按顺序运行全部步骤
*
* 用法：Stata 里先 cd 到 replication_jjyj2024 文件夹，再运行：do code/run_all.do
*
*   清洗（需要原始数据，见 DATA.md）
*     01_clean_entities.do   FactSet 公司信息、换 ID 对照表
*     02_clean_firms.do      加征关税行业、ST、CSMAR、Worldscope 2017 年财务指标
*     03_clean_panel.do      供应链关系 -> 关系对 x 月面板 -> 回归样本
*   回归与出图（只需要 data/clean/ 里的 panel_monthly.dta、analysis_sample.dta）
*     04_table2.do           表 1 样本对照、表 2、附表 3
*     05_figure1.do          图 1：断裂比例月度变化
*     06_event_study.do      附图 1：平行趋势检验
*
* 只有清洗后的数据时，把下面的 local clean 改成 0，只跑 04-06。
* ==========================================================================================
local clean 1

if `clean' {
    do "code/01_clean_entities.do"
    do "code/02_clean_firms.do"
    do "code/03_clean_panel.do"
}
do "code/04_table2.do"
do "code/05_figure1.do"
do "code/06_event_study.do"
