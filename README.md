# Interaction Effect of ABETA42 and Systolic Blood Pressure on Time-to-Alzheimer's Disease Conversion
How do vascular factors (systolic blood pressure, BMI, etc.)  influence the relationship between amyloid/tau pathology and cognitive decline in Alzheimer’s disease?

Background:
Amyloid/tau pathology refers to the abnormal buildup of amyloid-beta (Aβ) plaques and hyperphosphorylated tau tangles in the brain, the hallmark features of Alzheimer's disease (AD). These misfolded proteins lead to synapse loss, neurodegeneration, and cognitive decline. Both contribute to neuronal dysfunction and are often found together in AD patients. Vascular risk factors also show significant effects to cognitive decline and AD progression in research. This project looks at the interaction effect of Aβ/tau and vascular risk factors, including BMI, systolic blood pressure variability, history of cardiovascular disease, history of endocrine/metabolic disease, and smoking.

Data Preparation:
Aβ and ptau variables were log-transformed and standardized. BMI and systolic blood pressure measurements were standardized as well. These variables were chosen for analysis: time in years, AD conversion as an event (binary), log(Aβ), log(ptau), average real variability of systolic blood pressure, BMI, smoking (binary), history of cardiovascular disease (binary), history of endocrine/metabolic disease, BMI, age, gender, apoe4 allele presence (binary), and anti-amyloid treatment (binary). Based on VIF scores, these variables did not produce multicollinearity individually, not accounting for the interaction terms. Multiple imputation with n=50 was used to fill in the missing values on the data. The interaction effects between log(Aβ)/log(ptau) and the vascular risk factors produced high uncertainty. A separate dataset with non-missing values for Aβ and ptau variables was created to compare the cox hazard model with the dataset prepared with multiple imputation.

Dataset: https://adni.loni.usc.edu/data-samples/adni-data/

Cox Hazard Model:
With multiple imputations, log(Aβ), log(ptau), average real variability of systolic blood pressure, age, gender, and apoe4 allele presence produced significant parameter estimates, but not interaction effects. With the non-imputed data, the interaction effect between log(Aβ) and averge real variability of systolic blood pressure produced significant parameter estimate in addition to the same variables from multiple imputatiions but not age and the presence of apoe4 allele. With KM curves, the proportionality of the hazard model was confirmed.

Conclusion:
The interaction effect of abeta42 and average real variability of systolic blood pressure appeared with data without multiple imputations. Because of the high amount of observations with missing values for abeta42, performing multiple imputations increased uncertainty in the analysis. The result from the cox hazard model on the completed dataset should not be the primary inference. However, it suggests that the interaction effect is possibly significant on time to AD conversion. 
