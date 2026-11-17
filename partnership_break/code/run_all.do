* ==========================================================================================
* run_all.do —— 按顺序运行全部步骤
*
* 用法：Stata 里先 cd 到 partnership_break 文件夹，再运行：do code/run_all.do
*
*   清洗（需要原始数据，见 DATA.md）
*     01_clean_entities.do   FactSet 公司信息、换 ID 对照表（与 replication_jjyj2024 相同）
*     02_clean_firms.do      加征关税行业、ST、CSMAR、Worldscope 2017 年财务指标（与 replication_jjyj2024 相同）
*     03_clean_panel.do      合作关系 -> 关系对 x 月面板 -> 回归样本（全部合作关系 + 三大类）
*   回归与出图（只需要 data/clean/ 里的 panel_monthly.dta、analysis_*.dta）
*     04_main_reg.do         样本规模、主表四列
*     05_figure1.do          图 1：断裂比例月度变化
*     06_event_study.do      附图 1：平行趋势检验
*     07_types.do            三大类：主表四列
*
* 只有清洗后的数据时，把下面的 local clean 改成 0，只跑 04-07。
* ==========================================================================================
local clean 1

if `clean' {
    do "code/01_clean_entities.do"
    do "code/02_clean_firms.do"
    do "code/03_clean_panel.do"
}
do "code/04_main_reg.do"
do "code/05_figure1.do"
do "code/06_event_study.do"
do "code/07_types.do"
