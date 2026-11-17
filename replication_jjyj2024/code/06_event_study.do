* ==========================================================================================
* 06_event_study.do —— 论文附图 1：平行趋势检验（论文式 (2)）
*
* 输入：$CLEAN/analysis_sample.dta（03 生成）
* 输出：$OUT/figures/appendix_figure1_event_study.png
*       $OUT/tables/appendix_figure1_coefs.csv   每个相对月份的系数、标准误、95% 置信区间
*
* 论文式 (2)：Break_ijt = Σ_p β_p T(p) x Impact_ij + Σ_p γ_p T(p) x X_i + Σ_p δ_p T(p) x X_j + 年月 FE + 关系对 FE
*   p = -6, ..., +6，以 p = -1 为基期；早于 -6 的记为 -6，晚于 +6 的记为 +6。
*   相对月份 = 年月 - 供应商所在行业首次加征关税生效的月份。
*   论文没有说明对照组的相对月份怎么定义；这里与论文写法的 Post 一致，相对月份只对处理组（Impact = 1）定义，
*   对照组的 T(p) 全为 0。X 为两边 2017 年的 5 项特征（已在回归样本上缩尾）。标准误按关系对聚类。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l06
log using "$OUT/logs/06_event_study.log", replace text name(l06)

use "$CLEAN/analysis_sample.dta", clear
gen int k = max(min(t - fem, 6), -6) if impact == 1

* 处理组每个相对月份有多少观测、多少断裂
preserve
    keep if impact == 1
    collapse (count) n = break (sum) n_break = break (mean) rate = break, by(k)
    format rate %6.4f
    di as txt "处理组：每个相对月份的关系对 x 月、断裂次数、断裂率"
    list, noobs
restore

* T(p) x Impact 与 T(p) x X（p = -1 为基期，不进回归）
local Ev ""
local Kv ""
forvalues q = -6/6 {
    if `q' == -1 continue
    local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
    gen byte E_`nm' = impact == 1 & k == `q'
    local Ev "`Ev' E_`nm'"
    foreach v in size_i lev_i roa_i ato_i growth_i size_j lev_j roa_j ato_j growth_j {
        gen double K_`nm'_`v' = E_`nm' * w_`v'
        local Kv "`Kv' K_`nm'_`v'"
    }
}
reghdfe break `Ev' `Kv', absorb(pid t) vce(cluster pid)
test E_m6 E_m5 E_m4 E_m3 E_m2
local pre = r(p)
test E_p0 E_p1 E_p2 E_p3 E_p4 E_p5 E_p6
local pst = r(p)
di as txt _n "冲击前 5 个系数联合为 0 的检验：p = " %5.3f `pre' "；冲击后 7 个系数联合为 0 的检验：p = " %5.3f `pst'

* 整理系数并画图
tempname pf
tempfile coefs
postfile `pf' int p double(b se lo hi) using `coefs', replace
forvalues q = -6/6 {
    if `q' == -1 {
        post `pf' (`q') (0) (0) (0) (0)
    }
    else {
        local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
        post `pf' (`q') (_b[E_`nm']) (_se[E_`nm']) (_b[E_`nm'] - 1.96 * _se[E_`nm']) (_b[E_`nm'] + 1.96 * _se[E_`nm'])
    }
}
postclose `pf'
use `coefs', clear
format b se lo hi %8.4f
list, noobs
export delimited using "$OUT/tables/appendix_figure1_coefs.csv", replace

twoway (rcap lo hi p, lcolor(black) lpattern(dash)) ///
       (connected b p, lcolor(black) mcolor(black) msymbol(Oh)), ///
       yline(0, lcolor(gs8) lpattern(dash)) xline(-1, lcolor(gs8) lpattern(dash)) ///
       xlabel(-6(1)6) ylabel(, format(%3.1f) angle(0)) ///
       xtitle("距离美国贸易政策实施月份") ytitle("估计系数", margin(r=4)) legend(off) ///
       graphregion(color(white)) plotregion(color(white)) xsize(9) ysize(5.5)
graph export "$OUT/figures/appendix_figure1_event_study.png", replace width(1800)

log close l06
