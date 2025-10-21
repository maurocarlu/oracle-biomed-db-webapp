-- Oracle OR-DBMS schema generated from UML (object types, subtypes, object tables, association tables with REF/SCOPE)
-- Note: this script assumes an empty schema. If you need a re-run, drop objects first in dependency order.
-- Decision highlights:
-- - person_typ is the supertype; donor_typ and researcher_typ are subtypes (UNDER).
-- - 1..* relationships are modeled by placing a REF to the "1" side inside the "many" type.
-- - M:N / association entities (analyze, affected, assign, cause, writes, consider) are separate tables of object types with REF columns.
-- - REF columns use SCOPE IS <object_table> to restrict target tables.
-- - Attribute name "type" in biological_data_typ is renamed to data_type to avoid quoted identifiers.
-- - Some cardinalities like "at least one child" per parent can require triggers; here we enforce NOT NULL and uniqueness where possible.

prompt Creating base object types (supertype and subtypes)

CREATE OR REPLACE TYPE person_typ AS OBJECT (
  CF        CHAR(16),
  name      VARCHAR2(100),
  surname   VARCHAR2(100),
  birth     DATE
) NOT FINAL;
/

CREATE OR REPLACE TYPE donor_typ UNDER person_typ (
  sex       CHAR(1),
  age       NUMBER(3)
);
/

CREATE OR REPLACE TYPE researcher_typ UNDER person_typ ();
/

prompt Creating entity object types

CREATE OR REPLACE TYPE disease_typ AS OBJECT (
  id              NUMBER,
  name            VARCHAR2(200),
  discovery_date  DATE,
  description     CLOB
);
/

-- Note: attribute "type" renamed to data_type
CREATE OR REPLACE TYPE biological_data_typ AS OBJECT (
  id            NUMBER,
  name          VARCHAR2(200),
  condition     VARCHAR2(200),
  is_required   CHAR(1),
  description   CLOB,
  position      VARCHAR2(100),
  data_type     VARCHAR2(100),
  density       NUMBER,
  donor_ref     REF donor_typ
);
/

CREATE OR REPLACE TYPE treatment_typ AS OBJECT (
  id                  NUMBER,
  name                VARCHAR2(200),
  success_percentage  NUMBER(5,2)
);
/

CREATE OR REPLACE TYPE experiment_typ AS OBJECT (
  id                   NUMBER,
  exper_date           DATE, -- from UML: "date"
  is_positive          CHAR(1),
  effect_description   VARCHAR2(1000),
  disease_ref          REF disease_typ,
  treatment_ref        REF treatment_typ
);
/

CREATE OR REPLACE TYPE drugs_typ AS OBJECT (
  id          NUMBER,
  name        VARCHAR2(200),
  description CLOB
);
/

CREATE OR REPLACE TYPE allergy_typ AS OBJECT (
  id    NUMBER,
  name  VARCHAR2(200)
);
/

CREATE OR REPLACE TYPE publication_typ AS OBJECT (
  DOI        VARCHAR2(120),
  publisher  VARCHAR2(200),
  quality    VARCHAR2(50),
  title      VARCHAR2(300)
);
/

CREATE OR REPLACE TYPE future_work_typ AS OBJECT (
  id        NUMBER,
  title     VARCHAR2(300),
  exp_ref   REF experiment_typ,
  pub_ref   REF publication_typ
);
/

prompt Creating association object types (relationship entities)

CREATE OR REPLACE TYPE affected_typ AS OBJECT (
  id           NUMBER,
  bio_ref      REF biological_data_typ,
  disease_ref  REF disease_typ
);
/

CREATE OR REPLACE TYPE analyze_typ AS OBJECT (
  id        NUMBER,
  bio_ref   REF biological_data_typ,
  exp_ref   REF experiment_typ
);
/

CREATE OR REPLACE TYPE assign_typ AS OBJECT (
  id             NUMBER,
  treatment_ref  REF treatment_typ,
  drug_ref       REF drugs_typ
);
/

CREATE OR REPLACE TYPE cause_typ AS OBJECT (
  id           NUMBER,
  drug_ref     REF drugs_typ,
  allergy_ref  REF allergy_typ
);
/

CREATE OR REPLACE TYPE writes_typ AS OBJECT (
  id               NUMBER,
  publication_ref  REF publication_typ,
  researcher_ref   REF researcher_typ
);
/

CREATE OR REPLACE TYPE consider_typ AS OBJECT (
  id               NUMBER,
  future_work_ref  REF future_work_typ,
  researcher_ref   REF researcher_typ
);
/

prompt Creating object tables for entities

-- Store each subtype in its own object table for clean scoping of REFs
CREATE TABLE donors_tab OF donor_typ (
  CF PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE researchers_tab OF researcher_typ (
  CF PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE disease_tab OF disease_typ (
  id PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE drugs_tab OF drugs_typ (
  id PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE allergy_tab OF allergy_typ (
  id PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE publication_tab OF publication_typ (
  DOI PRIMARY KEY
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE treatment_tab OF treatment_typ (
  id PRIMARY KEY,
  name NOT NULL,
  success_percentage NOT NULL
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE experiment_tab OF experiment_typ (
  id PRIMARY KEY,
  disease_ref NOT NULL,
  treatment_ref NOT NULL,
  SCOPE FOR (disease_ref) IS disease_tab,
  SCOPE FOR (treatment_ref) IS treatment_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE biological_data_tab OF biological_data_typ (
  id PRIMARY KEY,
  donor_ref NOT NULL,
  SCOPE FOR (donor_ref) IS donors_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE future_work_tab OF future_work_typ (
  id PRIMARY KEY,
  title NOT NULL,
  exp_ref NOT NULL,
  pub_ref NOT NULL,
  SCOPE FOR (exp_ref) IS experiment_tab,
  SCOPE FOR (pub_ref) IS publication_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

prompt Creating association tables with REF/SCOPE and uniqueness

CREATE TABLE affected_tab OF affected_typ (
  id PRIMARY KEY,
  bio_ref NOT NULL,
  disease_ref NOT NULL,
  -- UNIQUE(bio_ref, disease_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (bio_ref) IS biological_data_tab,
  SCOPE FOR (disease_ref) IS disease_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE analyze_tab OF analyze_typ (
  id PRIMARY KEY,
  bio_ref NOT NULL,
  exp_ref NOT NULL,
  -- UNIQUE(bio_ref, exp_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (bio_ref) IS biological_data_tab,
  SCOPE FOR (exp_ref) IS experiment_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE assign_tab OF assign_typ (
  id PRIMARY KEY,
  treatment_ref NOT NULL,
  drug_ref NOT NULL,
  -- UNIQUE(treatment_ref, drug_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (treatment_ref) IS treatment_tab,
  SCOPE FOR (drug_ref) IS drugs_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE cause_tab OF cause_typ (
  id PRIMARY KEY,
  drug_ref NOT NULL,
  allergy_ref NOT NULL,
  -- UNIQUE(drug_ref, allergy_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (drug_ref) IS drugs_tab,
  SCOPE FOR (allergy_ref) IS allergy_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE writes_tab OF writes_typ (
  id PRIMARY KEY,
  publication_ref NOT NULL,
  researcher_ref NOT NULL,
  -- UNIQUE(publication_ref, researcher_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (publication_ref) IS publication_tab,
  SCOPE FOR (researcher_ref) IS researchers_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

CREATE TABLE consider_tab OF consider_typ (
  id PRIMARY KEY,
  future_work_ref NOT NULL,
  researcher_ref NOT NULL,
  -- UNIQUE(future_work_ref, researcher_ref) not allowed on REF: enforced via trigger below
  SCOPE FOR (future_work_ref) IS future_work_tab,
  SCOPE FOR (researcher_ref) IS researchers_tab
) OBJECT IDENTIFIER IS PRIMARY KEY;

prompt Schema creation complete.


CREATE SEQUENCE affected_tab_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE analyze_tab_seq  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE assign_tab_seq   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE cause_tab_seq    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE writes_tab_seq   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE consider_tab_seq START WITH 1 INCREMENT BY 1;

prompt Adding CHECK constraints for enumerations and ranges

-- BR1: BiologicalData.condition in {control, disease}
ALTER TABLE biological_data_tab
  ADD CONSTRAINT chk_bd_condition
  CHECK (LOWER(condition) IN ('control','disease'));

-- BR3: BiologicalData.is_required in {Y,N}
ALTER TABLE biological_data_tab
  ADD CONSTRAINT chk_bd_is_required
  CHECK (UPPER(is_required) IN ('Y','N'));

-- BR4: Experiment.is_positive in {Y,N}
ALTER TABLE experiment_tab
  ADD CONSTRAINT chk_experiment_is_positive
  CHECK (UPPER(is_positive) IN ('Y','N'));

-- BR7: Publication.quality in {top,middle,low}
ALTER TABLE publication_tab
  ADD CONSTRAINT chk_publication_quality
  CHECK (LOWER(quality) IN ('top','middle','low'));

-- BR8: BiologicalData.density > 0
ALTER TABLE biological_data_tab
  ADD CONSTRAINT chk_bd_density_pos
  CHECK (density > 0);

-- BR6: Treatment.success_percentage integer in [0,100]
ALTER TABLE treatment_tab
  ADD CONSTRAINT chk_treatment_success
  CHECK (success_percentage BETWEEN 0 AND 100 AND success_percentage = TRUNC(success_percentage));

-- BR2: BiologicalData.data_type in {organ, tissue}
ALTER TABLE biological_data_tab
  ADD CONSTRAINT chk_bd_data_type
  CHECK (LOWER(data_type) IN ('organ','tissue'));

-- No explicit is_useful attribute: by assumption, all Future Works are useful if created; enforce positivity via trigger below.

prompt Adding triggers for cross-entity business rules

-- BR12: Experiment.exper_date >= Disease.discovery_date for attempted disease
CREATE OR REPLACE TRIGGER trg_experiment_date_vs_disease
BEFORE INSERT OR UPDATE OF exper_date, disease_ref ON experiment_tab
FOR EACH ROW
DECLARE
  v_discovery_date DATE;
BEGIN
  SELECT d.discovery_date
    INTO v_discovery_date
    FROM disease_tab d
   WHERE REF(d) = :NEW.disease_ref;

  IF :NEW.exper_date < v_discovery_date THEN
    RAISE_APPLICATION_ERROR(-20001, 'Experiment date must be on or after the Disease discovery_date');
  END IF;
END;
/

-- BR13: Disease.discovery_date not in the future
CREATE OR REPLACE TRIGGER trg_disease_discovery_not_future
BEFORE INSERT OR UPDATE OF discovery_date ON disease_tab
FOR EACH ROW
BEGIN
  IF :NEW.discovery_date > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20002, 'Disease discovery_date cannot be in the future');
  END IF;
END;
/

-- BR9 (part 1): Affected rows only for BiologicalData with condition = 'disease'
CREATE OR REPLACE TRIGGER trg_affected_insert_check_condition
BEFORE INSERT OR UPDATE OF bio_ref ON affected_tab
FOR EACH ROW
DECLARE
  v_condition VARCHAR2(200);
BEGIN
  SELECT b.condition
    INTO v_condition
    FROM biological_data_tab b
   WHERE REF(b) = :NEW.bio_ref;

  IF LOWER(v_condition) <> 'disease' THEN
    RAISE_APPLICATION_ERROR(-20003, 'Affected link allowed only for BiologicalData with condition = disease');
  END IF;
END;
/

-- BR9 (part 2): Prevent deleting the last Affected when BD.condition = disease
CREATE OR REPLACE TRIGGER trg_affected_prevent_delete_last
BEFORE DELETE ON affected_tab
FOR EACH ROW
DECLARE
  v_condition VARCHAR2(200);
  v_cnt NUMBER;
BEGIN
  SELECT b.condition
    INTO v_condition
    FROM biological_data_tab b
   WHERE REF(b) = :OLD.bio_ref;

  IF LOWER(v_condition) = 'disease' THEN
    SELECT COUNT(*)
      INTO v_cnt
      FROM affected_tab a
     WHERE a.bio_ref = :OLD.bio_ref
       AND NOT (a.bio_ref = :OLD.bio_ref AND a.disease_ref = :OLD.disease_ref);

    IF v_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'Cannot delete the last Affected row for a diseased BiologicalData');
    END IF;
  END IF;
END;
/

-- Enforce: any Future Work must reference a positive experiment
CREATE OR REPLACE TRIGGER trg_future_work_requires_positive_exp
BEFORE INSERT OR UPDATE OF exp_ref ON future_work_tab
FOR EACH ROW
DECLARE
  v_is_pos CHAR(1);
BEGIN
  SELECT e.is_positive INTO v_is_pos
  FROM experiment_tab e
  WHERE REF(e) = :NEW.exp_ref;

  IF UPPER(v_is_pos) <> 'Y' THEN
    RAISE_APPLICATION_ERROR(-20011, 'FutureWork requires a positive Experiment');
  END IF;
END;
/

-- BR14 (part 1): On Analyze insert/update, ensure BD is diseased and matches Experiment.disease
CREATE OR REPLACE TRIGGER trg_analyze_consistency
BEFORE INSERT OR UPDATE OF bio_ref, exp_ref ON analyze_tab
FOR EACH ROW
DECLARE
  v_condition VARCHAR2(200);
  v_cnt NUMBER;
BEGIN
  -- BD must not be control
  SELECT b.condition INTO v_condition FROM biological_data_tab b WHERE REF(b) = :NEW.bio_ref;
  IF LOWER(v_condition) = 'control' THEN
    RAISE_APPLICATION_ERROR(-20005, 'Control BiologicalData cannot be analyzed in experiments attempting a disease');
  END IF;

  -- There must exist Affected(BD, Experiment.disease)
  SELECT COUNT(*) INTO v_cnt
  FROM affected_tab a
  WHERE a.bio_ref = :NEW.bio_ref
    AND a.disease_ref = (
          SELECT e.disease_ref FROM experiment_tab e WHERE REF(e) = :NEW.exp_ref
        );

  IF v_cnt = 0 THEN
    RAISE_APPLICATION_ERROR(-20006, 'BiologicalData must be affected by the same disease attempted by the Experiment');
  END IF;
END;
/

-- BR14 (part 2): Prevent deleting Affected if there are Analyze rows relying on it
CREATE OR REPLACE TRIGGER trg_affected_block_if_analyze_exists
BEFORE DELETE ON affected_tab
FOR EACH ROW
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM analyze_tab z
  WHERE z.bio_ref = :OLD.bio_ref
    AND EXISTS (
      SELECT 1 FROM experiment_tab e
      WHERE REF(e) = z.exp_ref
        AND e.disease_ref = :OLD.disease_ref
    );

  IF v_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20007, 'Cannot remove Affected: existing Analyze rows require this disease link');
  END IF;
END;
/

-- Uniqueness enforcement triggers for REF pairs (since UNIQUE on REF is not allowed)

CREATE OR REPLACE TRIGGER trg_aff_uni
FOR INSERT OR UPDATE OF bio_ref, disease_ref ON affected_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (bio_id NUMBER, disease_id NUMBER);
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_b REF biological_data_typ, p_d REF disease_typ) IS
    v_b NUMBER; v_d NUMBER;
  BEGIN
    SELECT b.id INTO v_b FROM biological_data_tab b WHERE REF(b) = p_b;
    SELECT d.id INTO v_d FROM disease_tab d WHERE REF(d) = p_d;
    g_idx := g_idx + 1;
    g_pairs(g_idx).bio_id := v_b;
    g_pairs(g_idx).disease_id := v_d;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.bio_ref, :NEW.disease_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM affected_tab a
      WHERE DEREF(a.bio_ref).id = g_pairs(i).bio_id
        AND DEREF(a.disease_ref).id = g_pairs(i).disease_id;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20030, 'Duplicate Affected (bio,disease)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_analyze_uni
FOR INSERT OR UPDATE OF bio_ref, exp_ref ON analyze_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (bio_id NUMBER, exp_id NUMBER);
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_b REF biological_data_typ, p_e REF experiment_typ) IS
    v_b NUMBER; v_e NUMBER;
  BEGIN
    SELECT b.id INTO v_b FROM biological_data_tab b WHERE REF(b) = p_b;
    SELECT e.id INTO v_e FROM experiment_tab e WHERE REF(e) = p_e;
    g_idx := g_idx + 1;
    g_pairs(g_idx).bio_id := v_b;
    g_pairs(g_idx).exp_id := v_e;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.bio_ref, :NEW.exp_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM analyze_tab a
      WHERE DEREF(a.bio_ref).id = g_pairs(i).bio_id
        AND DEREF(a.exp_ref).id = g_pairs(i).exp_id;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20031, 'Duplicate Analyze (bio,experiment)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_assign_uni
FOR INSERT OR UPDATE OF treatment_ref, drug_ref ON assign_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (treatment_id NUMBER, drug_id NUMBER);
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_t REF treatment_typ, p_d REF drugs_typ) IS
    v_t NUMBER; v_d NUMBER;
  BEGIN
    SELECT t.id INTO v_t FROM treatment_tab t WHERE REF(t) = p_t;
    SELECT d.id INTO v_d FROM drugs_tab d WHERE REF(d) = p_d;
    g_idx := g_idx + 1;
    g_pairs(g_idx).treatment_id := v_t;
    g_pairs(g_idx).drug_id := v_d;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.treatment_ref, :NEW.drug_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM assign_tab a
      WHERE DEREF(a.treatment_ref).id = g_pairs(i).treatment_id
        AND DEREF(a.drug_ref).id = g_pairs(i).drug_id;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20032, 'Duplicate Assign (treatment,drug)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_cause_uni
FOR INSERT OR UPDATE OF drug_ref, allergy_ref ON cause_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (drug_id NUMBER, allergy_id NUMBER);
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_dr REF drugs_typ, p_al REF allergy_typ) IS
    v_dr NUMBER; v_al NUMBER;
  BEGIN
    SELECT d.id INTO v_dr FROM drugs_tab d WHERE REF(d) = p_dr;
    SELECT a.id INTO v_al FROM allergy_tab a WHERE REF(a) = p_al;
    g_idx := g_idx + 1;
    g_pairs(g_idx).drug_id := v_dr;
    g_pairs(g_idx).allergy_id := v_al;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.drug_ref, :NEW.allergy_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM cause_tab c
      WHERE DEREF(c.drug_ref).id = g_pairs(i).drug_id
        AND DEREF(c.allergy_ref).id = g_pairs(i).allergy_id;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20033, 'Duplicate Cause (drug,allergy)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_writes_uni
FOR INSERT OR UPDATE OF publication_ref, researcher_ref ON writes_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (doi VARCHAR2(120), cf CHAR(16));
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_p REF publication_typ, p_r REF researcher_typ) IS
    v_doi VARCHAR2(120); v_cf CHAR(16);
  BEGIN
    SELECT p.DOI INTO v_doi FROM publication_tab p WHERE REF(p) = p_p;
    SELECT r.CF  INTO v_cf  FROM researchers_tab r WHERE REF(r) = p_r;
    g_idx := g_idx + 1;
    g_pairs(g_idx).doi := v_doi;
    g_pairs(g_idx).cf  := v_cf;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.publication_ref, :NEW.researcher_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM writes_tab w
      WHERE DEREF(w.publication_ref).DOI = g_pairs(i).doi
        AND DEREF(w.researcher_ref).CF  = g_pairs(i).cf;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20034, 'Duplicate Writes (publication,researcher)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_consider_uni
FOR INSERT OR UPDATE OF future_work_ref, researcher_ref ON consider_tab
COMPOUND TRIGGER
  TYPE pair_rec IS RECORD (fw_id NUMBER, cf CHAR(16));
  TYPE pair_tab IS TABLE OF pair_rec INDEX BY PLS_INTEGER;
  g_pairs pair_tab;
  g_idx PLS_INTEGER := 0;

  PROCEDURE add_pair(p_fw REF future_work_typ, p_r REF researcher_typ) IS
    v_fw NUMBER; v_cf CHAR(16);
  BEGIN
    SELECT f.id INTO v_fw FROM future_work_tab f WHERE REF(f) = p_fw;
    SELECT r.CF INTO v_cf FROM researchers_tab r WHERE REF(r) = p_r;
    g_idx := g_idx + 1;
    g_pairs(g_idx).fw_id := v_fw;
    g_pairs(g_idx).cf    := v_cf;
  END;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN
      add_pair(:NEW.future_work_ref, :NEW.researcher_ref);
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
    v_cnt NUMBER;
  BEGIN
    FOR i IN 1..g_idx LOOP
      SELECT COUNT(*) INTO v_cnt
      FROM consider_tab c
      WHERE DEREF(c.future_work_ref).id = g_pairs(i).fw_id
        AND DEREF(c.researcher_ref).CF  = g_pairs(i).cf;
      IF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20035, 'Duplicate Consider (future_work,researcher)');
      END IF;
    END LOOP;
  END AFTER STATEMENT;
END;
/

-- Indexes
-- Indexes for OP2
CREATE INDEX idx_bd_density ON biological_data_tab(density);
-- Indexes for OP3 
CREATE INDEX idx_assign_treatment_ref ON assign_tab(treatment_ref);
CREATE INDEX idx_cause_drug_ref       ON cause_tab(drug_ref);
-- Indexes for OP4 
CREATE INDEX idx_aff_dis_bio ON affected_tab(disease_ref, bio_ref);
CREATE INDEX idx_analyze_bio ON analyze_tab(bio_ref);
CREATE INDEX idx_fw_exp      ON future_work_tab(exp_ref);
-- Indexes for OP5
CREATE INDEX idx_pub_quality ON publication_tab(quality);
CREATE INDEX idx_writes_publication_ref ON writes_tab(publication_ref);
CREATE INDEX idx_consider_researcher_ref ON consider_tab(researcher_ref);

