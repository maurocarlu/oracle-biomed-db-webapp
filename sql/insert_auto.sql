CREATE OR REPLACE PROCEDURE PopulateDatabase (
  p_num_donors          IN NUMBER,
  p_num_researchers     IN NUMBER,
  p_num_diseases        IN NUMBER,
  p_num_drugs           IN NUMBER,
  p_num_allergies       IN NUMBER,
  p_num_publications    IN NUMBER,
  p_num_treatments      IN NUMBER,
  p_num_experiments     IN NUMBER,
  p_num_biological_data IN NUMBER,
  p_num_future_works    IN NUMBER
) IS
  v_cf        CHAR(16);
  v_start_date DATE := TO_DATE('1950-01-01', 'YYYY-MM-DD');
  v_end_date   DATE := SYSDATE;
BEGIN

  -- Popolamento Donors
  FOR i IN 1..p_num_donors LOOP
    v_cf := 'D' || LPAD(i, 15, '0');
    INSERT INTO donors_tab VALUES (
      donor_typ(
        v_cf,
        'Name'||i,
        'Surname'||i,
        v_start_date + TRUNC(DBMS_RANDOM.VALUE(0, (v_end_date - v_start_date))),
        CASE MOD(i, 2) WHEN 0 THEN 'M' ELSE 'F' END,
        ROUND(DBMS_RANDOM.VALUE(18, 90))
      )
    );
  END LOOP;
  COMMIT;

  -- Popolamento Researchers
  FOR i IN 1..p_num_researchers LOOP
    v_cf := 'R' || LPAD(i, 15, '0');
    INSERT INTO researchers_tab VALUES (
      researcher_typ(
        v_cf,
        'ResName'||i,
        'ResSurname'||i,
        v_start_date + TRUNC(DBMS_RANDOM.VALUE(0, (v_end_date - v_start_date)))
      )
    );
  END LOOP;
  COMMIT;

  -- Popolamento Diseases
  FOR i IN 1..p_num_diseases LOOP
    INSERT INTO disease_tab VALUES (
      disease_typ(
        i,
        'Disease'||i,
        v_start_date + TRUNC(DBMS_RANDOM.VALUE(0, (v_end_date - 365 - v_start_date))), -- Ensure discovery date is not too recent
        'Description for disease '||i
      )
    );
  END LOOP;
  COMMIT;

  -- Popolamento Drugs
  FOR i IN 1..p_num_drugs LOOP
    INSERT INTO drugs_tab VALUES (
      drugs_typ(
        i,
        'Drug'||i,
        'Description for drug '||i
      )
    );
  END LOOP;
  COMMIT;

  -- Popolamento Allergies
  FOR i IN 1..p_num_allergies LOOP
    INSERT INTO allergy_tab VALUES (
      allergy_typ(
        i,
        'Allergy'||i
      )
    );
  END LOOP;
  COMMIT;

  -- Popolamento Publications
  -- Nuova distribuzione: top 5%, middle 60%, low 35%
  FOR i IN 1..p_num_publications LOOP
    DECLARE
      v_r NUMBER := DBMS_RANDOM.VALUE(0,1); -- [0,1)
      v_quality VARCHAR2(10);
    BEGIN
      IF v_r < 0.05 THEN               -- 5%
        v_quality := 'top';
      ELSIF v_r < 0.65 THEN            -- 0.05 - 0.65 => 60%
        v_quality := 'middle';
      ELSE                             -- 0.65 - 1 => 35%
        v_quality := 'low';
      END IF;

      INSERT INTO publication_tab VALUES (
        publication_typ(
          'DOI/'||DBMS_RANDOM.STRING('A', 10)||'/'||i,
          'Publisher'||MOD(i, 50),
          v_quality,
          'Title of publication '||i
        )
      );
    END;
  END LOOP;
  COMMIT;

  -- Popolamento Treatments
  FOR i IN 1..p_num_treatments LOOP
    INSERT INTO treatment_tab VALUES (
      treatment_typ(
        i,
        'Treatment'||i,
        TRUNC(DBMS_RANDOM.VALUE(0, 101))
      )
    );
  END LOOP;
  COMMIT;

  -- Assign (collega trattamenti e farmaci)
  FOR t IN (SELECT REF(tr) as treat_ref FROM treatment_tab tr) LOOP
    DECLARE
        v_drug_ref REF drugs_typ;
    BEGIN
        SELECT r INTO v_drug_ref
        FROM (
          SELECT REF(dr) r FROM drugs_tab dr ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;
        INSERT INTO assign_tab VALUES (assign_typ(assign_tab_seq.NEXTVAL, t.treat_ref, v_drug_ref));
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;
  END LOOP;
  COMMIT;

  -- Popolamento Biological Data
  FOR i IN 1..p_num_biological_data LOOP
    DECLARE
      v_donor_ref REF donor_typ;
    BEGIN
      SELECT r INTO v_donor_ref
      FROM (
        SELECT REF(d) r FROM donors_tab d ORDER BY DBMS_RANDOM.VALUE
      )
      WHERE ROWNUM = 1;

      INSERT INTO biological_data_tab VALUES (
        biological_data_typ(
          i,
          'BioData'||i,
          CASE MOD(i, 2) WHEN 0 THEN 'disease' ELSE 'control' END,
          CASE MOD(i, 2) WHEN 0 THEN 'Y' ELSE 'N' END,
          'Description for biological data '||i,
          'Position'||i,
          CASE MOD(i, 2) WHEN 0 THEN 'organ' ELSE 'tissue' END,
          DBMS_RANDOM.VALUE(0.1, 100),
          v_donor_ref
        )
      );
    END;
  END LOOP;
  COMMIT;

  -- Popolamento Experiments
  FOR i IN 1..p_num_experiments LOOP
    DECLARE
      v_disease_ref REF disease_typ;
      v_treatment_ref REF treatment_typ;
      v_discovery_date DATE;
    BEGIN
      SELECT r, discovery_date INTO v_disease_ref, v_discovery_date
      FROM (
        SELECT REF(d) r, d.discovery_date FROM disease_tab d ORDER BY DBMS_RANDOM.VALUE
      )
      WHERE ROWNUM = 1;

      SELECT r INTO v_treatment_ref
      FROM (
        SELECT REF(t) r FROM treatment_tab t ORDER BY DBMS_RANDOM.VALUE
      )
      WHERE ROWNUM = 1;

      INSERT INTO experiment_tab VALUES (
        experiment_typ(
          i,
          v_discovery_date + TRUNC(DBMS_RANDOM.VALUE(1, 3650)), -- Experiment date after discovery
          CASE MOD(i, 2) WHEN 0 THEN 'Y' ELSE 'N' END,
          'Effect description for experiment '||i,
          v_disease_ref,
          v_treatment_ref
        )
      );
    END;
  END LOOP;
  COMMIT;

  -- Popolamento Associazioni
  -- Affected (collega dati biologici con condizione 'disease' a una malattia)
  FOR bd IN (SELECT id, REF(b) as bio_ref FROM biological_data_tab b WHERE b.condition = 'disease') LOOP
    DECLARE
        v_disease_ref REF disease_typ;
    BEGIN
        SELECT r INTO v_disease_ref
        FROM (
          SELECT REF(d) r FROM disease_tab d ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;

        INSERT INTO affected_tab VALUES (
            affected_typ(affected_tab_seq.NEXTVAL, bd.bio_ref, v_disease_ref)
        );
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; -- Ignora duplicati
    END;
  END LOOP;
  COMMIT;


  -- Cause (collega farmaci e allergie)
  FOR i IN 1..p_num_drugs LOOP
    DECLARE
        v_drug_ref REF drugs_typ;
        v_allergy_ref REF allergy_typ;
    BEGIN
      SELECT REF(d) INTO v_drug_ref FROM drugs_tab d WHERE d.id = i;
      SELECT r INTO v_allergy_ref FROM (
        SELECT REF(a) r FROM allergy_tab a ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1;
      INSERT INTO cause_tab VALUES (cause_typ(cause_tab_seq.NEXTVAL, v_drug_ref, v_allergy_ref));
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;
  END LOOP;
  COMMIT;

  -- Writes (collega ricercatori e pubblicazioni)
  FOR p IN (SELECT REF(p) AS pub_ref FROM publication_tab p)
  LOOP
    DECLARE
      v_res_ref REF researcher_typ;
    BEGIN
      SELECT r INTO v_res_ref FROM (
       SELECT REF(r) r FROM researchers_tab r ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1;
      INSERT INTO writes_tab VALUES (writes_typ(writes_tab_seq.NEXTVAL, p.pub_ref, v_res_ref));
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;
  END LOOP;
  COMMIT;

  -- Analyze (collega dati biologici ed esperimenti)
  FOR aff IN (SELECT bio_ref, disease_ref FROM affected_tab) LOOP
    DECLARE
      v_exp_ref REF experiment_typ;
    BEGIN
      SELECT r INTO v_exp_ref FROM (
        SELECT REF(e) r FROM experiment_tab e WHERE e.disease_ref = aff.disease_ref ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1;

      IF v_exp_ref IS NOT NULL THEN
        INSERT INTO analyze_tab VALUES (analyze_typ(analyze_tab_seq.NEXTVAL, aff.bio_ref, v_exp_ref));
      END IF;
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;
  END LOOP;
  COMMIT;
  
  -- Popolamento Future Work (richiede esperimenti positivi)
  FOR i IN 1..p_num_future_works LOOP
    DECLARE
      v_exp_ref REF experiment_typ;
      v_pub_ref REF publication_typ;
    BEGIN
      SELECT r INTO v_exp_ref
      FROM (
        SELECT REF(e) r FROM experiment_tab e WHERE e.is_positive = 'Y' ORDER BY DBMS_RANDOM.VALUE
      )
      WHERE ROWNUM = 1;

      SELECT r INTO v_pub_ref FROM (
        SELECT REF(p) r FROM publication_tab p ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1;

      INSERT INTO future_work_tab VALUES (
        future_work_typ(
          i,
          'Future work title '||i,
          v_exp_ref,
          v_pub_ref
        )
      );
    END;
  END LOOP;
  COMMIT;
  
  -- Consider (collega future works e ricercatori)
  FOR f IN (SELECT REF(f) AS fw_ref FROM future_work_tab f)
  LOOP
    DECLARE
      v_res_ref REF researcher_typ;
    BEGIN
      SELECT r INTO v_res_ref FROM (
       SELECT REF(r) r FROM researchers_tab r ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1;
      INSERT INTO consider_tab VALUES (consider_typ(consider_tab_seq.NEXTVAL, f.fw_ref, v_res_ref));
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;
  END LOOP;
  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Popolamento completato con successo.');

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Errore durante il popolamento: ' || SQLERRM);
    ROLLBACK;
END PopulateDatabase;
/

SET SERVEROUTPUT ON;

BEGIN
  PopulateDatabase(
    p_num_donors          => 10000,  
    p_num_researchers     => 4000, 
    p_num_diseases        => 1200,   
    p_num_drugs           => 250,    
    p_num_allergies       => 350,    
    p_num_publications    => 8000,  
    p_num_treatments      => 1200,   
    p_num_experiments     => 15000,  
    p_num_biological_data => 12000,  
    p_num_future_works    => 18000   
  );
END;
/


--Select count(*) FROM donors_tab;
--Select count(*) FROM researchers_tab;
--Select count(*) FROM disease_tab;
--Select count(*) FROM drugs_tab;
--Select count(*) FROM allergy_tab;
--Select count(*) FROM publication_tab;
--Select count(*) FROM treatment_tab;
--Select count(*) FROM experiment_tab;
--Select count(*) FROM biological_data_tab;
--Select count(*) FROM future_work_tab;

--Select count(*) FROM affected_tab;
--Select count(*) FROM analyze_tab;
--Select count(*) FROM assign_tab;
--Select count(*) FROM cause_tab;
--Select count(*) FROM writes_tab;
--Select count(*) FROM consider_tab;