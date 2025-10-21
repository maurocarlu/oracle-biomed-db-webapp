-- Tests for CHECK constraints and triggers on Oracle OR-DBMS schema
-- This script intentionally executes statements that should fail and report errors.
-- It uses SAVEPOINT/ROLLBACK and continues on error to avoid persisting side effects.

whenever sqlerror continue
set echo on
set define off

prompt === Test BR1: BiologicalData.condition must be control/disease ===
savepoint sp_bd_condition;
INSERT INTO biological_data_tab (id, name, condition, is_required, description, position, data_type, density, donor_ref)
SELECT 1001,'Invalid condition','Baseline','Y','Should fail','arm','organ',1.0, REF(d)
  FROM donors_tab d WHERE ROWNUM = 1;
rollback to sp_bd_condition;

prompt === Test BR2: BiologicalData.data_type must be organ/tissue ===
savepoint sp_bd_datatype;
INSERT INTO biological_data_tab (id, name, condition, is_required, description, position, data_type, density, donor_ref)
SELECT 1002,'Invalid data_type','disease','Y','Should fail','arm','numeric',1.0, REF(d)
  FROM donors_tab d WHERE ROWNUM = 1;
rollback to sp_bd_datatype;

prompt === Test BR3: BiologicalData.is_required must be Y/N ===
savepoint sp_bd_isreq;
INSERT INTO biological_data_tab (id, name, condition, is_required, description, position, data_type, density, donor_ref)
SELECT 1003,'Invalid is_required','disease','T','Should fail','arm','organ',1.0, REF(d)
  FROM donors_tab d WHERE ROWNUM = 1;
rollback to sp_bd_isreq;

prompt === Test BR4: Experiment.is_positive must be Y/N ===
savepoint sp_exp_posval;
INSERT INTO experiment_tab (id, exper_date, is_positive, effect_description, disease_ref, treatment_ref)
SELECT 100, DATE '2023-01-01', 'X', 'Should fail', REF(di), REF(t)
  FROM disease_tab di, treatment_tab t WHERE di.id=1 AND t.id=1;
rollback to sp_exp_posval;

prompt === Test BR6: Treatment.success_percentage integer in [0,100] ===
savepoint sp_tr_success1;
INSERT INTO treatment_tab (id, name, success_percentage) VALUES (200, 'Bad Success >100', 105);
rollback to sp_tr_success1;

prompt === Test BR7: Publication.quality must be in {top,middle,low} ===
savepoint sp_pub_quality;
INSERT INTO publication_tab (DOI, publisher, quality, title)
VALUES ('10.1000/test-badq','ACM','Q1','Bad Quality Value');
rollback to sp_pub_quality;

prompt === Test BR8: BiologicalData.density must be > 0 ===
savepoint sp_bd_density;
INSERT INTO biological_data_tab (id, name, condition, is_required, description, position, data_type, density, donor_ref)
SELECT 1004,'Invalid density','disease','Y','Should fail','arm','organ',0, REF(d)
  FROM donors_tab d WHERE ROWNUM = 1;
rollback to sp_bd_density;

prompt === Test BR9-1: Affected only for diseased BiologicalData ===
savepoint sp_aff_ctrl;
INSERT INTO affected_tab (id, bio_ref, disease_ref)
SELECT 100, REF(b), REF(d) FROM biological_data_tab b, disease_tab d
 WHERE b.id=7 AND d.id=1; -- b7 is control
rollback to sp_aff_ctrl;

prompt === Test BR9-2: Affected delete blocked if Analyze depends on it ===
savepoint sp_aff_del_block;
DELETE FROM affected_tab WHERE id = 1; -- b1-e1 analyze exists referencing same disease
rollback to sp_aff_del_block;

prompt === Test BR11: FutureWork must be linked to at least one Publication ===
savepoint sp_fw_pub;
DECLARE
  v_new_id NUMBER;
  v_exp_ref REF experiment_typ;
BEGIN
  SELECT NVL(MAX(id), 0) + 1 INTO v_new_id FROM future_work_tab;
  -- Get a positive experiment
  SELECT REF(e) INTO v_exp_ref FROM experiment_tab e WHERE e.is_positive = 'Y' AND ROWNUM = 1;
  -- Try to insert FutureWork WITHOUT publication (should fail if trigger exists)
  INSERT INTO future_work_tab (id, title, exp_ref, pub_ref)
  VALUES (v_new_id, 'Test FW without publication', v_exp_ref, NULL);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('BR11: ' || SQLERRM);
END;
/
rollback to sp_fw_pub;

prompt === Test BR12: Experiment.exper_date >= Disease.discovery_date ===
savepoint sp_exp_date;
DECLARE
  v_new_id NUMBER;
BEGIN
  SELECT NVL(MAX(id), 0) + 1 INTO v_new_id FROM experiment_tab;
  INSERT INTO experiment_tab (id, exper_date, is_positive, effect_description, disease_ref, treatment_ref)
  SELECT v_new_id, di.discovery_date - 10, 'Y', 'Too early vs discovery', REF(di), REF(t)
    FROM disease_tab di, treatment_tab t WHERE di.id = 1 AND t.id = 1;
END;
/
rollback to sp_exp_date;

prompt === Test BR13: Disease.discovery_date cannot be in the future ===
savepoint sp_dis_future;
INSERT INTO disease_tab (id, name, discovery_date, description)
VALUES (1000,'Time Traveler', SYSDATE + 10, 'Should fail (future date)');
rollback to sp_dis_future;

prompt === Test FW trigger: FutureWork requires a positive Experiment ===
savepoint sp_fw_positive;
DECLARE
  v_new_id NUMBER;
BEGIN
  SELECT NVL(MAX(id), 0) + 1 INTO v_new_id FROM future_work_tab;
  INSERT INTO future_work_tab (id, title, exp_ref, pub_ref)
  SELECT v_new_id, 'Should fail on negative experiment', REF(e), REF(p)
    FROM experiment_tab e, publication_tab p 
    WHERE e.is_positive = 'N' AND p.quality = 'top' AND ROWNUM = 1;
END;
/
rollback to sp_fw_positive;

prompt === Test BR14-1: Analyze cannot use control BiologicalData ===
savepoint sp_an_ctrl;
INSERT INTO analyze_tab (id, bio_ref, exp_ref)
SELECT 100, REF(b), REF(e) FROM biological_data_tab b, experiment_tab e
 WHERE b.id=7 AND e.id=1; -- b7 is control
rollback to sp_an_ctrl;

prompt === Test BR14-2: Analyze requires Affected(BD, Experiment.disease) ===
savepoint sp_an_affect_mismatch;
DECLARE
  v_new_id NUMBER;
  v_bio_ref REF biological_data_typ;
  v_exp_ref REF experiment_typ;
BEGIN
  SELECT NVL(MAX(id), 0) + 1 INTO v_new_id FROM analyze_tab;
  -- Find a diseased BD and an experiment targeting a DIFFERENT disease
  SELECT REF(b), REF(e) INTO v_bio_ref, v_exp_ref
  FROM biological_data_tab b, experiment_tab e, affected_tab a
  WHERE b.condition = 'disease'
    AND DEREF(a.bio_ref).id = b.id
    AND DEREF(e.disease_ref).id != DEREF(a.disease_ref).id
    AND ROWNUM = 1;
  INSERT INTO analyze_tab (id, bio_ref, exp_ref) VALUES (v_new_id, v_bio_ref, v_exp_ref);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Skip BR14-2 test: no suitable disease mismatch found in data');
END;
/
rollback to sp_an_affect_mismatch;

--------------------------------------------------------------------------
-- TEST UNIQUENESS CONSTRAINTS
--------------------------------------------------------------------------
prompt === Test Uniqueness: Affected duplicate (bio_ref, disease_ref) ===
savepoint sp_aff_dup;
INSERT INTO affected_tab (id, bio_ref, disease_ref)
SELECT 901, a.bio_ref, a.disease_ref FROM affected_tab a WHERE ROWNUM = 1;
rollback to sp_aff_dup;

prompt === Test Uniqueness: Analyze duplicate (bio_ref, exp_ref) ===
savepoint sp_an_dup2;
INSERT INTO analyze_tab (id, bio_ref, exp_ref)
SELECT 902, an.bio_ref, an.exp_ref FROM analyze_tab an WHERE ROWNUM = 1;
rollback to sp_an_dup2;

prompt === Test Uniqueness: Assign duplicate (treatment_ref, drug_ref) ===
savepoint sp_assign_dup2;
INSERT INTO assign_tab (id, treatment_ref, drug_ref)
SELECT 903, asg.treatment_ref, asg.drug_ref FROM assign_tab asg WHERE ROWNUM = 1;
rollback to sp_assign_dup2;

prompt === Test Uniqueness: Cause duplicate (drug_ref, allergy_ref) ===
savepoint sp_cause_dup2;
INSERT INTO cause_tab (id, drug_ref, allergy_ref)
SELECT 904, c.drug_ref, c.allergy_ref FROM cause_tab c WHERE ROWNUM = 1;
rollback to sp_cause_dup2;

prompt === Test Uniqueness: Writes duplicate (publication_ref, researcher_ref) ===
savepoint sp_writes_dup2;
INSERT INTO writes_tab (id, publication_ref, researcher_ref)
SELECT 905, w.publication_ref, w.researcher_ref FROM writes_tab w WHERE ROWNUM = 1;
rollback to sp_writes_dup2;

prompt === Test Uniqueness: Consider duplicate (future_work_ref, researcher_ref) ===
savepoint sp_consider_dup2;
INSERT INTO consider_tab (id, future_work_ref, researcher_ref)
SELECT 906, c.future_work_ref, c.researcher_ref FROM consider_tab c WHERE ROWNUM = 1;
rollback to sp_consider_dup2;

prompt Tests finished.
