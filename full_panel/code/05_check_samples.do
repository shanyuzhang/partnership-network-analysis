* ==========================================================================================
* 05_check_samples.do —— 核对：从完整面板按 s_ 变量取出的行，与另外两个文件夹的样本逐行逐变量相同
*
* 输入：$CLEAN/full_panel.dta
*       $CLEAN_JJYJ/panel_monthly.dta、analysis_sample.dta（replication_jjyj2024）
*       $CLEAN_PT/panel_monthly.dta、analysis_sample.dta、analysis_K.dta、analysis_C.dta、analysis_M.dta（partnership_break）
* 输出：$OUT/tables/check_samples.csv   每个样本：原文件行数、从完整面板取出的行数、对不上的行数、
*                                      比较的变量数、不一致的格子数（后三项都应为 0，行数应相同）
*
* 做法：
*   - 取出的行改成原文件的变量名（replication_jjyj2024 里 post 叫 post_e、postimpact 叫 Post）；
*   - 回归样本里在样本内缩尾的 w_ 变量、postimpact x 财务变量（post*）、us_post、us_tariff、firm_m，
*     用两个文件夹里同样的代码在取出的行上重新生成；
*   - 按 focal partner t 一一对上，比较原文件里的每个变量（pid 是各自编号的，不比）；
*   - 三大类样本的 break、first17 用这一类自己的 break_K、first17_K 等；三大类样本里的 break1-3
*     完整面板里没有（分析里没用到），不比。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l05
log using "$OUT/logs/05_check_samples.log", replace text name(l05)

capture program drop _cmp
program define _cmp
    * 用法：_cmp 样本名 原文件 ["不比较的变量"]；内存里是从完整面板取出、已改好变量名的数据
    args sname file skip
    quietly {
        local n_full = _N
        tempfile mine
        save `mine'
        describe using "`file'", varlist
        local vars `r(varlist)'
        local nocmp pid `skip'
        local vars : list vars - nocmp
        use `vars' using "`file'", clear
        local n_orig = _N
        local keys focal partner t
        local cmp : list vars - keys
        foreach v of local cmp {
            rename `v' o_`v'
        }
        merge 1:1 focal partner t using `mine', keepusing(`cmp')
        count if _merge != 3
        local n_unm = r(N)
        local nd = 0
        foreach v of local cmp {
            count if _merge == 3 & o_`v' != `v'
            local nd = `nd' + r(N)
            if r(N) > 0 noisily di as err "  `v'：" r(N) " 处不一致"
        }
        local nv : word count `cmp'
    }
    di as txt "`sname'：原文件 `n_orig' 行，完整面板取出 `n_full' 行，对不上 `n_unm' 行；比较 `nv' 个变量，不一致 `nd' 处"
    post $PH ("`sname'") (`n_orig') (`n_full') (`n_unm') (`nv') (`nd')
end

tempfile res
global PH ph
postfile $PH str40 sample long(n_orig n_full n_unmatched) int nvars long ndiff using `res', replace

* ---- replication_jjyj2024：图 1 面板、回归样本 ----
use if s_jjyj_panel using "$CLEAN/full_panel.dta", clear
rename (post postimpact) (post_e Post)
_cmp "replication_jjyj2024/panel_monthly" "$CLEAN_JJYJ/panel_monthly.dta"

use if s_jjyj using "$CLEAN/full_panel.dta", clear
rename (post postimpact) (post_e Post)
foreach v in size lev roa ato growth {
    foreach k in i j {
        quietly _pctile `v'_`k', p(1 99)
        gen double w_`v'_`k' = min(max(`v'_`k', r(r1)), r(r2)) if `v'_`k' < .
    }
}
_cmp "replication_jjyj2024/analysis_sample" "$CLEAN_JJYJ/analysis_sample.dta"

* ---- partnership_break：图 1 面板、回归样本（全部合作关系、三大类）----
use if s_pt_panel using "$CLEAN/full_panel.dta", clear
gen byte us_post   = us * post
gen byte us_tariff = us * tariff_i
_cmp "partnership_break/panel_monthly" "$CLEAN_PT/panel_monthly.dta"

foreach g in ALL K C M {
    if "`g'" == "ALL" {
        use if s_pt using "$CLEAN/full_panel.dta", clear
        local f analysis_sample
        local skip ""
    }
    else {
        use if s_pt_`g' using "$CLEAN/full_panel.dta", clear
        replace break   = break_`g'
        replace first17 = first17_`g'
        local f analysis_`g'
        local skip "break1 break2 break3"
    }
    gen byte us_post   = us * post
    gen byte us_tariff = us * tariff_i
    foreach v in size lev roa ato growth {
        quietly _pctile `v'_i, p(1 99)
        gen double w_`v'_i = min(max(`v'_i, r(r1)), r(r2)) if `v'_i < .
        gen double post`v' = postimpact * w_`v'_i
    }
    egen long firm_m = group(focal t)
    _cmp "partnership_break/`f'" "$CLEAN_PT/`f'.dta" "`skip'"
}

postclose $PH
use `res', clear
list, noobs abbreviate(12)
export delimited using "$OUT/tables/check_samples.csv", replace
assert n_orig == n_full & n_unmatched == 0 & ndiff == 0
di as txt "全部一致"

log close l05
