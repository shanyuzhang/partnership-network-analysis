* ==========================================================================================
* 08_types_desc.do —— 三大类（知识 K、资本 C、市场 M）各自断了多少：描述统计，不分处理组
*
* 输入：$CLEAN/analysis_sample.dta、analysis_K.dta、analysis_C.dta、analysis_M.dta（03 生成）
*       ../full_panel/data/clean/full_panel.dta：full_panel 文件夹生成的完整面板（清洗与本文件夹相同，
*       不截时间、不做样本筛选；Drive 的 full_panel 文件夹里也有）。没有这个文件时只输出月断裂率。
* 输出：$OUT/tables/types_survival.csv    存续率：a 月存在的关系，b 月这一类合作仍然存在的比例
*       $OUT/tables/types_stock.csv       每月存在的关系数，2016m1-2024m7
*       $OUT/tables/types_batch.csv       断裂次数，其中整批结束的次数
*       $OUT/tables/types_break_rate.csv  回归样本的月断裂率：处理组 / 对照组 x 冲击前 / 后
*
* 口径：
*   - 存续率、数量、整批结束用完整面板里 A 股企业 x 境外企业的全部合作关系（rel = partnership），不做样本筛选。
*     某月“存在” = 这一类至少有一段关系当月有效（与 03 相同）；中间断过、b 月之前又恢复的也算仍然存在。
*   - 整批结束：同一家 A 股企业同一个月断掉 5 个及以上这一类关系。rate_ex_batch 把 a 月之后第一次断裂
*     落在整批结束里、b 月也不存在的关系从分母里去掉。
*   - rate_ok 只看 a 月满足回归样本条件的关系（筛选与 panel_monthly.dta 相同，下面用 assert 核对），
*     b 月是否存在不看条件。
*   - 月断裂率用回归样本，冲击前 / 后按 post 分（加征行业为本行业首次生效月起，其余行业为 2018m7 起）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l08
log using "$OUT/logs/08_types_desc.log", replace text name(l08)

local fp "$REPO/../full_panel/data/clean/full_panel.dta"

* ==========================================================================================
* 1-3. 存续率、每月数量、整批结束（完整面板）
* ==========================================================================================
capture confirm file "`fp'"
if _rc {
    di as txt "没有找到完整面板 `fp'，跳过存续率、数量和整批结束三张表"
}
else {
    use rel pid focal t pt_K pt_C pt_M break break_K break_C break_M fA fin late st_y tariff_i xi pcty s_pt_panel ///
        if rel == 3 using "`fp'", clear
    gen byte ok = fA == 1 & fin == 0 & late == 0 & st_y != 1 & tariff_i < . & xi == 1 & !inlist(pcty, "CN", "", "OFF")
    assert ok == s_pt_panel if inrange(t, tm(2017m1), tm(2020m6))
    gen byte pt_ALL = 1
    gen byte break_ALL = break
    tempfile base
    save `base'

    * ---- 每月存在的关系数 ----
    collapse (sum) n_ALL = pt_ALL n_K = pt_K n_C = pt_C n_M = pt_M, by(t)
    format t %tm
    export delimited using "$OUT/tables/types_stock.csv", replace
    list if inlist(t, tm(2016m12), tm(2018m6), tm(2019m12), tm(2024m7)), noobs clean

    * ---- 整批结束、存续率 ----
    tempname ps pb
    tempfile surv bat
    postfile `ps' str3 typ str7(a b) long(n k lost_batch n_ok k_ok) using `surv', replace
    postfile `pb' str3 typ str14 period long(nbrk nbatch) using `bat', replace
    foreach g in ALL K C M {
        use if pt_`g' == 1 using `base', clear
        quietly bysort focal t: egen int nft = total(break_`g' == 1)
        gen byte batch = break_`g' == 1 & nft >= 5
        foreach w in "2017m1 2018m6" "2018m7 2019m12" {
            local p1 : word 1 of `w'
            local p2 : word 2 of `w'
            quietly count if break_`g' == 1 & inrange(t, tm(`p1'), tm(`p2'))
            local nb = r(N)
            quietly count if batch & inrange(t, tm(`p1'), tm(`p2'))
            post `pb' ("`g'") ("`p1'-`p2'") (`nb') (r(N))
        }
        foreach w in "2016m12 2018m6" "2018m6 2019m12" "2018m6 2024m7" {
            local a : word 1 of `w'
            local b : word 2 of `w'
            quietly {
                gen byte ina = t == tm(`a')
                gen byte inb = t == tm(`b')
                bysort pid: egen byte hb = max(inb)                       // b 月存在
                gen tb = t if break_`g' == 1 & t >= tm(`a') & t < tm(`b')
                bysort pid: egen ftb = min(tb)                             // a 月之后第一次断裂
                gen byte fbb = t == ftb & batch
                bysort pid: egen byte hfb = max(fbb)                       // 第一次断裂是整批结束
                count if ina
                local n = r(N)
                count if ina & hb
                local k = r(N)
                count if ina & !hb & hfb
                local lb = r(N)
                count if ina & ok
                local n2 = r(N)
                count if ina & ok & hb
                local k2 = r(N)
                drop ina inb hb tb ftb fbb hfb
            }
            post `ps' ("`g'") ("`a'") ("`b'") (`n') (`k') (`lb') (`n2') (`k2')
        }
    }
    postclose `ps'
    postclose `pb'

    use `surv', clear
    gen double rate          = k / n
    gen double rate_ex_batch = k / (n - lost_batch)
    gen double rate_ok       = k_ok / n_ok
    order typ a b n k rate lost_batch rate_ex_batch n_ok k_ok rate_ok
    format rate rate_ex_batch rate_ok %5.3f
    list, noobs sepby(typ)
    export delimited using "$OUT/tables/types_survival.csv", replace

    use `bat', clear
    list, noobs sepby(typ)
    export delimited using "$OUT/tables/types_batch.csv", replace
}

* ==========================================================================================
* 4. 回归样本的月断裂率（%）：处理组 / 对照组 x 冲击前 / 后
* ==========================================================================================
tempname pr
tempfile br
postfile `pr' str3 typ byte(impact post) long(n nbrk) double rate using `br', replace
foreach g in ALL K C M {
    local fn = cond("`g'" == "ALL", "analysis_sample", "analysis_`g'")
    use "$CLEAN/`fn'.dta", clear
    forvalues i = 0/1 {
        forvalues p = 0/1 {
            quietly count if impact == `i' & post == `p'
            local n = r(N)
            quietly count if impact == `i' & post == `p' & break == 1
            post `pr' ("`g'") (`i') (`p') (`n') (r(N)) (100 * r(N) / `n')
        }
    }
}
postclose `pr'
use `br', clear
format rate %6.3f
list, noobs sepby(typ)
export delimited using "$OUT/tables/types_break_rate.csv", replace

log close l08
