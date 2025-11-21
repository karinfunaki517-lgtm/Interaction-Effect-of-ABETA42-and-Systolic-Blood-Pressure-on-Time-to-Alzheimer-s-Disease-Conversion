proc import datafile = "/home/u64295411/ADPI/All_Subjects_ANTIAMYTX_11Nov2025.csv"
out = anti_amyloid
dbms = csv;
proc import datafile = "/home/u64295411/ADPI/All_Subjects_DXSUM_11Nov2025.csv"
out = diag_sum
dbms = csv;
proc import datafile = "/home/u64295411/ADPI/All_Subjects_PTDEMOG_11Nov2025.csv"
out = demographic
dbms = csv;
proc import datafile = "/home/u64295411/ADPI/All_Subjects_UPENNBIOMK_ROCHE_ELECSYS_11Nov2025.csv"
out = biomarker
dbms = csv;
proc import datafile = "/home/u64295411/ADPI/All_Subjects_VITALS_11Nov2025.csv"
out = vitals
dbms = csv;

proc import datafile = "/home/u64295411/ADPI/All_Subjects_APOERES_12Nov2025.csv"
out = apoeres
dbms = csv;

proc import datafile = "/home/u64295411/ADPI/All_Subjects_MEDHIST_20Nov2025.csv"
out = medhist
dbms = csv;

run;

proc sort data = medhist
out = medhist_sorted;
by PTID;
run;

proc sort data = apoeres
out = apoeres_sorted;
by PTID;
run;

proc sort data = anti_amyloid
out = anti_amyloid_sorted;
by PTID;
run;
*TXREC: 1 = I confirm this participant received anti-amyloid treatment, requires discontinuation of study medication;



proc sort data = demographic
	out = demographic_sorted;
	by PTID;
run;

*Only need one data on gender and date of birth;

proc sort data = diag_sum
out = diag_sum_sorted;
by PTID;
run;

proc sort data = biomarker
out = biomarker_sorted;
by PTID;
run;

proc sort data = vitals
out = vitals_sorted;
by PTID;
run;

data data_all;
merge medhist_sorted apoeres_sorted anti_amyloid_sorted diag_sum_sorted demographic_sorted biomarker_sorted vitals_sorted;
by PTID;
run;

data data_subset;
    set data_all(keep=
        PTID VISCODE EXAMDATE DIAGNOSIS
        ABETA42 PTAU
        VSBPSYS VSWEIGHT VSHEIGHT VSHTUNIT VSWTUNIT
        PTDOB PTGENDER GENOTYPE TXREC
        MH16SMOK MH9ENDO MH4CARD
    );
run;
	
data data_subset;
set data_subset;
EXAMDATE_formated = input(EXAMDATE, YYMMDD10.);
format EXAMDATE_formated date9.;
run;

data data_subset;
set data_subset;
	if VSWEIGHT = -4 then VSWEIGHT = .;
	else if VSWTUNIT = 1 then weight_kg = VSWEIGHT * 0.453592;
    else if VSWTUNIT = 2 then weight_kg = VSWEIGHT;

    if VSHEIGHT = -4 then VSHEIGHT = .;
    else if VSHTUNIT = 1 then height_m = VSHEIGHT * 0.0254;
    else if VSHTUNIT = 2 then height_m = VSHEIGHT / 100;

    if height_m > 0 then BMI = weight_kg / (height_m**2);
drop VSHTUNIT VSHEIGHT VSWEIGHT VSWTUNIT; 
run;

data data_subset;
set data_subset;
	if find(GENOTYPE, '4') > 0 then APOE4 = 1;
	else if GENOTYPE = '' then APOE4 = .;
	else APOE4 = 0;
drop GENOTYPE;
run;

data data_subset;
set data_subset;
	
	if TXREC = '1' then txrec_bi = 1;
	else txrec_bi = 0;

	if PTGENDER = '1' then gender_bi = 1;
	else if PTGENDER = '2' then gender_bi = 0;
	else gender_bi = .;
	
drop TXREC PTGENDER;
run;

data data_subset;
set data_subset;
abeta42_num = input(ABETA42, best32.2);
ptau_num = input(PTAU, best32.2);
vsbpsys_num = input(VSBPSYS, best32.2);
bmi_num = input(BMI, best32.2);

drop ABETA42 PTAU VSBPSYS BMI;
run;

data sbp_diff;
    set data_subset;
    by PTID;
    lag_sbp = lag(vsbpsys_num);
    if first.PTID then lag_sbp = .;
    diff = abs(vsbpsys_num - lag_sbp);
run;


proc means data=sbp_diff noprint;
    by PTID;
    var vsbpsys_num diff;
    output out=sbp_var
        mean = mean_sbp
        std = sd_sbp
        cv = cv_sbp
        mean(diff) = arv_sbp;
run;

proc sql;
    create table data_with_sbpvar as
    select a.*, b.arv_sbp, b.sd_sbp
    from data_subset a
    left join sbp_var b
    on a.PTID = b.PTID;
quit;

proc sql;
    create table baseline_covariates as
    select 
        PTID,
        EXAMDATE_formated,
        abeta42_num,
        ptau_num,
        arv_sbp,
        sd_sbp,
        weight_kg,
        height_m,
        bmi_num,
        MH4CARD,
        MH9ENDO,
        MH16SMOK,
        PTDOB,
        gender_bi,
        APOE4,
        txrec_bi
    from data_with_sbpvar a
    where EXAMDATE_formated = (
        select min(EXAMDATE_formated)
        from data_with_sbpvar b
        where b.PTID = a.PTID
    );
quit;


proc sql;
	create table baseline as
	select PTID, min(EXAMDATE_formated) as baseline_date format = date9.
	from data_subset group by PTID;
quit;

proc sql;	
	create table first_ad as
	select PTID, min(EXAMDATE_formated) as first_ad_date format = date9.
	from data_subset
	where DIAGNOSIS = '3' group by PTID;
quit;
proc sql;
	create table last_visit as
	select PTID, max(EXAMDATE_formated) as last_date format = date9.
	from data_subset group by PTID;
quit;

proc sql;
  create table survival as
  select b.PTID, b.baseline_date,
         l.last_date,
         f.first_ad_date
  from baseline b
  left join last_visit l on b.PTID=l.PTID
  left join first_ad f on b.PTID=f.PTID;
quit;

data survival;
set survival;
if first_ad_date > baseline_date then event = 1;
else event = 0;

if event = 1 then time_years = (first_ad_date - baseline_date)/365.25;
else time_years = (last_date - baseline_date)/365.25;
run;	

proc sql;
create table final as
select s.*, c.*
  from survival s
  left join baseline_covariates c
  on s.PTID = c.PTID;
quit;

data final;
set final;
AGE = (baseline_date - PTDOB)/365.25;

drop PTOB;
run;

*Exclude observations with AD prevalent at baseline;

data final;
set final;
if baseline_date = first_ad_date then delete;
run;

*Transformation;

data final;
set final;
log_abeta = log(abeta42_num);
log_ptau = log(ptau_num);
run;

proc standard data = final mean = 0 std = 1 out = final_std;
var log_abeta log_ptau sd_sbp arv_sbp AGE bmi_num;
run;

data final_std;
set final_std;
abeta_arvsbp = log_abeta*arv_sbp;
abeta_sdsbp = log_abeta*sd_sbp;
abeta_bmi = log_abeta*bmi_num;
abeta_smoke = log_abeta*MH16SMOK;
abeta_card = log_abeta*MH4CARD;
abeta_endo = log_abeta*MH9ENDO;
ptau_arvsbp = log_ptau*arv_sbp;
ptau_sdbp = log_ptau*sd_sbp;
ptau_bmi = log_ptau*bmi_num;
ptau_smoke = log_ptau*MH16SMOK;
ptau_card = log_ptau*MH4CARD;
ptau_endo = log_ptau*MH9ENDO;
run;


data final_std;
set final_std;
y = rannor(123);
run;

data final_std;
set final_std;
smoke = input(MH16SMOK, 32.);
card = input(MH4CARD, 32.);
endo = input(MH9ENDO, 32.);
run;

*Multicollinearity;

proc reg data = final_std;
model y = log_abeta log_ptau arv_sbp bmi_num smoke card endo AGE gender_bi APOE4 txrec_bi / vif;
run;


data final_std;
set final_std(keep = time_years event 
	log_abeta log_ptau arv_sbp 
	abeta_arvsbp abeta_bmi abeta_smoke abeta_card abeta_endo 
	ptau_arvsbp ptau_bmi ptau_smoke ptau_card ptau_endo 
	bmi_num APOE4
	AGE gender_bi txrec_bi
	weight_kg height_m
	smoke card endo);
run;



*Multiple imputation;
proc means data = final_std nmiss;
run;

proc mi data = final_std nimpute = 0;
ods select misspattern;
run;

proc mi data = final_std nimpute = 50 seed = 100 out = mi_final;
var log_abeta log_ptau arv_sbp 
	abeta_arvsbp abeta_bmi abeta_smoke abeta_card abeta_endo 
	ptau_arvsbp ptau_bmi ptau_smoke ptau_card ptau_endo 
	bmi_num APOE4
	AGE gender_bi txrec_bi
	weight_kg height_m
	smoke card endo;
class gender_bi txrec_bi APOE4 smoke card endo;
fcs logistic(gender_bi txrec_bi APOE4 smoke card endo) 
reg(log_abeta log_ptau arv_sbp abeta_arvsbp abeta_bmi abeta_smoke abeta_card abeta_endo 
	ptau_arvsbp ptau_bmi ptau_smoke ptau_card ptau_endo bmi_num AGE) ;
run;

proc phreg data = mi_final;
class gender_bi(ref = '0') txrec_bi(ref = '0') smoke(ref = '0') card(ref = '0') endo(ref = '0');
model time_years*event(0) = log_abeta log_ptau arv_sbp 
	abeta_arvsbp abeta_bmi abeta_smoke abeta_card abeta_endo 
	ptau_arvsbp ptau_bmi ptau_smoke ptau_card ptau_endo 
	bmi_num APOE4
	AGE gender_bi txrec_bi
	smoke card endo/ ties = efron;
by _Imputation_;
ods output ParameterEstimates=a_final;
run;

*Final;
proc phreg data = mi_final;
class gender_bi(ref = '0') txrec_bi(ref = '0') smoke(ref = '0') card(ref = '0') endo(ref = '0');
model time_years*event(0) = log_abeta log_ptau arv_sbp 
	abeta_arvsbp APOE4 AGE gender_bi txrec_bi
	/ ties = efron;
by _Imputation_;
ods output ParameterEstimates=a_final;
run;

proc mianalyze parms=a_final;
modeleffects log_abeta log_ptau arv_sbp 
	abeta_arvsbp APOE4 AGE gender_bi txrec_bi;
run;


*Data without imputations;
data final_std_nomi;
set final_std;
if log_abeta = . then delete;
if log_ptau = . then delete;
run;

proc phreg data = final_std_nomi;
class gender_bi(ref = '0') txrec_bi(ref = '0');
model time_years*event(0) = log_abeta log_ptau arv_sbp 
	abeta_arvsbp gender_bi/ties = efron;

run;
*The interaction effect of abeta42 and the average real variability of systolic blood pressure
of participants throughout the study produced a hazard ratio of 1.178 with p value moderately significant 
based on alpha = 0.05;

*test for proportional hazard;

proc standard data = final_std_nomi mean = 0 std = 1 out = final_std_nomi;
var abeta_arvsbp;
run;
proc lifetest data = final_std_nomi plots = (s, lls) notable;
strata abeta_arvsbp(-20 to 20 by 20);
time time_years*event(0);
run;

*Conclusion: The interaction effect of abeta42 and average real variability of systolic blood pressure
appeared with data without multiple imputations. Because of the high amount of observations with 
missing values for abeta42, performing multiple imputations increased uncertainty in the analysis. The
result from the cox hazard model on the completed dataset should not be the primary inference. However,
it suggests that the interaction effect is possibly significant on time to AD conversion. 

