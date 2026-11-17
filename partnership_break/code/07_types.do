* ==========================================================================================
* 07_types.do —— 合作关系分三大类（知识 K、资本 C、市场 M）：主表四列
*
* 输入：$CLEAN/analysis_sample.dta（全部合作关系）、analysis_K.dta、analysis_C.dta、analysis_M.dta（03 生成）
* 输出：$OUT/tables/types_main_reg.tex、types_main_reg.csv
*
* 每一类的面板在 03 里单独建：某月“存在” = 这一类至少有一段关系当月有效；断裂 = 这一类本月存在、下个月不存在。
* 回归与 04 的主表完全相同（每一类的控制变量在自己的回归样本上缩尾）：
*   (1) postimpact；(2) + postsize postlev postroa postato postgrowth；(3) postimpact + 企业 x 月 FE；
*   (4) (3) + us us_post us_tariff。标准误按 A 股企业聚类。
* 表里只列 postimpact 的系数。处理组关系对太少时回归可能失败，表里留空。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l07
log using "$OUT/logs/07_types.log", replace text name(l07)

local X "postsize postlev postroa postato postgrowth"
local s1 "postimpact"
local s2 "postimpact `X'"
local s3 "postimpact"
local s4 "postimpact us us_post us_tariff"
local a1 "noabsorb"
local a2 "noabsorb"
local a3 "absorb(firm_m)"
local a4 "absorb(firm_m)"

tempname pf
tempfile res
postfile `pf' str3 typ byte col double(b se p) long(N nfirm ntr nbrk) using `res', replace

foreach g in ALL K C M {
    local fn = cond("`g'" == "ALL", "analysis_sample", "analysis_`g'")
    use "$CLEAN/`fn'.dta", clear
    forvalues c = 1/4 {
        capture quietly reghdfe break `s`c'', `a`c'' vce(cluster focal)
        if _rc {
            di as txt "`g' (`c')：回归失败（rc = " _rc "）"
            post `pf' ("`g'") (`c') (.) (.) (.) (.) (.) (.) (.)
            continue
        }
        if _se[postimpact] == 0 {
            di as txt "`g' (`c')：postimpact 与其他变量共线，被剔除"
            post `pf' ("`g'") (`c') (.) (.) (.) (e(N)) (e(N_clust)) (.) (.)
            continue
        }
        local b  = _b[postimpact]
        local se = _se[postimpact]
        local p  = 2 * ttail(e(df_r), abs(`b' / `se'))
        local N  = e(N)
        local nf = e(N_clust)
        tempvar es tg
        quietly gen byte `es' = e(sample)
        quietly egen byte `tg' = tag(pid) if `es' & impact == 1
        quietly count if `tg' == 1
        local ntr = r(N)
        quietly count if `es' & break == 1
        local nbrk = r(N)
        drop `es' `tg'
        post `pf' ("`g'") (`c') (`b') (`se') (`p') (`N') (`nf') (`ntr') (`nbrk')
        di as txt "`g' (`c')：postimpact = " %7.4f `b' " (" %6.4f `se' ") p = " %5.3f `p' ///
            "  N = " `N' "  A 股企业 = " `nf' "  处理组关系对 = " `ntr' "  断裂 = " `nbrk'
    }
}
postclose `pf'

use `res', clear
format b se %8.4f
format p %5.3f
list, noobs sepby(typ)
export delimited using "$OUT/tables/types_main_reg.csv", replace

* ---- LaTeX 表：每个类型三行（系数、标准误、观测值 / 处理组关系对）----
gen str12 star = cond(p < 0.01, "\sym{***}", cond(p < 0.05, "\sym{**}", cond(p < 0.10, "\sym{*}", "")))
tempname h
file open `h' using "$OUT/tables/types_main_reg.tex", write replace text
file write `h' "{" _n "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write `h' "\begin{tabular}{lcccc}" _n "\toprule" _n
file write `h' "Type & (1) & (2) & (3) & (4) \\" _n "\midrule" _n
foreach g in ALL K C M {
    if "`g'" == "ALL" local gl "All partnerships"
    if "`g'" == "K"   local gl "Knowledge (K)"
    if "`g'" == "C"   local gl "Capital (C)"
    if "`g'" == "M"   local gl "Market (M)"
    local r1 "`gl'"
    local r2 ""
    local r3 ""
    forvalues c = 1/4 {
        quietly levelsof b if typ == "`g'" & col == `c', local(bb) clean
        if "`bb'" == "" | "`bb'" == "." {
            local r1 "`r1' & "
            local r2 "`r2' & "
            local r3 "`r3' & "
            continue
        }
        quietly summarize b if typ == "`g'" & col == `c', meanonly
        local bv : display %9.4f r(mean)
        quietly summarize se if typ == "`g'" & col == `c', meanonly
        local sv : display %9.4f r(mean)
        quietly levelsof star if typ == "`g'" & col == `c', local(st) clean
        quietly summarize N if typ == "`g'" & col == `c', meanonly
        local nv : display %9.0fc r(mean)
        quietly summarize ntr if typ == "`g'" & col == `c', meanonly
        local tv : display %9.0fc r(mean)
        local r1 "`r1' & `=strtrim("`bv'")'`st'"
        local r2 "`r2' & (`=strtrim("`sv'")')"
        local r3 "`r3' & `=strtrim("`nv'")' / `=strtrim("`tv'")'"
    }
    file write `h' "`r1' \\" _n "`r2' \\" _n "`r3' \\" _n
    if "`g'" != "M" file write `h' "\addlinespace" _n
}
file write `h' "\midrule" _n
file write `h' "Controls (Post \(\times\) Impact \(\times\) X) & No & Yes & No & No \\" _n
file write `h' "Firm \(\times\) month FE & No & No & Yes & Yes \\" _n
file write `h' "US, US \(\times\) Post, US \(\times\) Tariff & No & No & No & Yes \\" _n
file write `h' "\bottomrule" _n
file write `h' "\multicolumn{5}{l}{\footnotesize Coefficient on Post \(\times\) Impact; SE clustered by A-share firm in parentheses; third row: observations / treated pairs.}\\" _n
file write `h' "\multicolumn{5}{l}{\footnotesize \sym{*} \(p<0.10\), \sym{**} \(p<0.05\), \sym{***} \(p<0.01\)}\\" _n
file write `h' "\end{tabular}" _n "}" _n
file close `h'
type "$OUT/tables/types_main_reg.tex"

log close l07
