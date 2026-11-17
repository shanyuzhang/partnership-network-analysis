* ==========================================================================================
* 06_event_study.do —— 附图 1（合作关系版）：平行趋势检验（论文式 (2)）
*
* 输入：$CLEAN/analysis_sample.dta、analysis_K.dta、analysis_C.dta、analysis_M.dta（03 生成）
* 输出：$OUT/figures/appendix_figure1_event_study.png（全部合作关系）
*       $OUT/tables/appendix_figure1_coefs.csv   每个类型 x 相对月份的系数、标准误、95% 置信区间
*       $OUT/tables/appendix_figure1_tests.csv   冲击前 5 个、冲击后 7 个系数分别联合为 0 的检验
*
* 论文式 (2)：Break_ijt = Σ_p β_p T(p) x Impact + Σ_p γ_p T(p) x X_i + 年月 FE + 关系对 FE
*   p = -6, ..., +6，以 p = -1 为基期；早于 -6 的记为 -6，晚于 +6 的记为 +6。
*   相对月份 = 年月 - A 股企业所在行业首次加征关税生效的月份。
*   与 replication_jjyj2024 相同：相对月份只对处理组（Impact = 1）定义，对照组的 T(p) 全为 0
*   （论文没有说明对照组怎么定义）。X_i 为 A 股企业 2017 年的 5 项特征（与主表第 (2) 列相同，已缩尾）。
*   标准误按关系对聚类（论文的写法）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l06
log using "$OUT/logs/06_event_study.log", replace text name(l06)

local XI "w_size_i w_lev_i w_roa_i w_ato_i w_growth_i"

tempname pc pt
tempfile coefs tests
postfile `pc' str3 typ int p double(b se lo hi) using `coefs', replace
postfile `pt' str3 typ double(pre_p post_p) long(N ntr) using `tests', replace

foreach g in ALL K C M {
    local fn = cond("`g'" == "ALL", "analysis_sample", "analysis_`g'")
    use "$CLEAN/`fn'.dta", clear
    gen int k = max(min(t - fem, 6), -6) if impact == 1

    di as txt _n "#################### `g' ####################"
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
        foreach v of local XI {
            gen double K_`nm'_`v' = E_`nm' * `v'
            local Kv "`Kv' K_`nm'_`v'"
        }
    }
    capture noisily reghdfe break `Ev' `Kv', absorb(pid t) vce(cluster pid)
    if _rc {
        di as txt "`g'：回归失败（rc = " _rc "）"
        post `pt' ("`g'") (.) (.) (.) (.)
        continue
    }
    local N = e(N)
    * 处理组关系对数：按回归样本（去掉单个观测的关系对之后）计
    tempvar tg
    quietly egen byte `tg' = tag(pid) if e(sample) & impact == 1
    quietly count if `tg' == 1
    local ntr = r(N)
    drop `tg'
    capture test E_m6 E_m5 E_m4 E_m3 E_m2
    local pre = cond(_rc, ., r(p))
    capture test E_p0 E_p1 E_p2 E_p3 E_p4 E_p5 E_p6
    local pst = cond(_rc, ., r(p))
    di as txt "`g'：冲击前 5 个系数联合为 0 的检验 p = " %5.3f `pre' "；冲击后 7 个系数联合为 0 的检验 p = " %5.3f `pst'
    post `pt' ("`g'") (`pre') (`pst') (`N') (`ntr')
    forvalues q = -6/6 {
        if `q' == -1 {
            post `pc' ("`g'") (`q') (0) (0) (0) (0)
        }
        else {
            local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
            local bb = _b[E_`nm']
            local ss = _se[E_`nm']
            if `ss' == 0 {
                local bb = .
                local ss = .
            }
            post `pc' ("`g'") (`q') (`bb') (`ss') (`bb' - 1.96 * `ss') (`bb' + 1.96 * `ss')
        }
    }
}
postclose `pc'
postclose `pt'

use `tests', clear
format pre_p post_p %5.3f
di as txt _n "===== 联合检验汇总 ====="
list, noobs
export delimited using "$OUT/tables/appendix_figure1_tests.csv", replace

use `coefs', clear
format b se lo hi %8.4f
export delimited using "$OUT/tables/appendix_figure1_coefs.csv", replace
di as txt _n "===== 全部合作关系的系数 ====="
list if typ == "ALL", noobs

twoway (rcap lo hi p, lcolor(black) lpattern(dash)) ///
       (connected b p, lcolor(black) mcolor(black) msymbol(Oh)) if typ == "ALL", ///
       yline(0, lcolor(gs8) lpattern(dash)) xline(-1, lcolor(gs8) lpattern(dash)) ///
       xlabel(-6(1)6) ylabel(, format(%3.1f) angle(0)) ///
       xtitle("距离美国贸易政策实施月份") ytitle("估计系数", margin(r=4)) legend(off) ///
       graphregion(color(white)) plotregion(color(white)) xsize(9) ysize(5.5)
graph export "$OUT/figures/appendix_figure1_event_study.png", replace width(1800)

log close l06
