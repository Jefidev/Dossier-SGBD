 create or replace TYPE nestedChar IS TABLE OF varchar2(4000);
 /

DECLARE
  fichierId  utl_file.file_type;


  TYPE colonne IS RECORD
  (
    nom  varchar2(50),
    type varchar2(50)
  );

  TYPE tabCol IS TABLE OF colonne INDEX BY BINARY_INTEGER;
  nomColonne tabCol;


  TYPE result IS RECORD
  (
    max NUMBER,
    min NUMBER,
    avg NUMBER,
    ecart NUMBER,
    mediane NUMBER,
    totVal NUMBER,
    quantile100 NUMBER,
    quantile1000 NUMBER,
    valNull NUMBER
  );
  donnee result;

  valVide NUMBER;

  cpt NUMBER;
  parc NUMBER;
  i NUMBER;

  TYPE resultChain IS TABLE OF varchar2(4000) INDEX BY BINARY_INTEGER;
  valeursUniques resultChain;
  chaineRegex resultChain;

  id nestedChar := nestedChar();
  nom nestedChar := nestedChar();
  image nestedChar := nestedChar();
  idPerso nestedChar := nestedChar();
  nomPerso nestedChar := nestedChar();

  requeteBlock varchar2(4000);

  morceauRecup varchar2(4000);

  resultParse OWA_TEXT.VC_ARR;
  
BEGIN
  fichierId := utl_file.fopen ('MOVIEDIRECTORY', 'Rapport.txt', 'W');

  utl_file.put_line (fichierId, 'RAPPORT FILM');
  utl_file.put_line (fichierId, '------------');


  i:=1;
  SELECT regexp_substr(ACTORS, '^\[\[(.*)\]\]$', 1, 1, '', 1) BULK COLLECT INTO chaineRegex FROM movies_ext WHERE ROWNUM <= 1000;

  FOR cpt IN chaineRegex.FIRST..chaineRegex.LAST LOOP
    IF(LENGTH(chaineRegex(cpt)) > 0) THEN
      LOOP
        morceauRecup := regexp_substr(chaineRegex(cpt), '(.*?)(\|\||$)', 1, i, '', 1);
        EXIT WHEN morceauRecup IS NULL;

        IF OWA_PATTERN.MATCH(morceauRecup, '^(.*),,(.*),,(.*),,(.*),,(.*)$', resultParse) THEN
          IF resultParse(1) NOT MEMBER OF id THEN
            id.extend();
            nom.extend();
            image.extend();
            idPerso.extend();
            nomPerso.extend();
            id(id.COUNT):=resultParse(1);
            nom(nom.COUNT):=resultParse(2);
            idPerso(idPerso.COUNT):= resultParse(3);
            nomPerso(idPerso.COUNT):= resultParse(4);
            image(image.COUNT):= resultParse(5);
          END IF;            
        END IF;
        i:= i + 1;
      END LOOP;
      i:= 1;
    END IF;
  END LOOP;

  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM TABLE(id);

  SELECT COUNT(*) INTO valVide FROM TABLE(id) WHERE COLUMN_VALUE = '';

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'id :');

  utl_file.put_line (fichierId, '             MAX:  ' || donnee.max);
  utl_file.put_line (fichierId, '             MIN:  ' || donnee.min);
  utl_file.put_line (fichierId, '         MOYENNE:  ' || ROUND(donnee.avg,2));
  utl_file.put_line (fichierId, '      ECART-TYPE:  ' || ROUND(donnee.ecart,2));
  utl_file.put_line (fichierId, '         MEDIANE:  ' || ROUND(donnee.mediane,2));
  utl_file.put_line (fichierId, '     NBR VALEURS:  ' || (donnee.totVal + donnee.valNull));
  utl_file.put_line (fichierId, '    VALEURS NULL:  ' || donnee.valNull);
  utl_file.put_line (fichierId, 'VALEURS NON NULL:  ' || donnee.totVal);
  utl_file.put_line (fichierId, '   VALEURS VIDES:  ' || (valVide));
  utl_file.put_line (fichierId, '    100-QUANTILE:  ' || (donnee.quantile100));
  utl_file.put_line (fichierId, '   1000-QUANTILE:  ' || (donnee.quantile1000));

  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM TABLE(nom);

  SELECT COUNT(*) INTO valVide FROM TABLE(nom) WHERE COLUMN_VALUE = '';

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'nom');

  utl_file.put_line (fichierId, '             MAX:  ' || donnee.max);
  utl_file.put_line (fichierId, '             MIN:  ' || donnee.min);
  utl_file.put_line (fichierId, '         MOYENNE:  ' || ROUND(donnee.avg,2));
  utl_file.put_line (fichierId, '      ECART-TYPE:  ' || ROUND(donnee.ecart,2));
  utl_file.put_line (fichierId, '         MEDIANE:  ' || ROUND(donnee.mediane,2));
  utl_file.put_line (fichierId, '     NBR VALEURS:  ' || (donnee.totVal + donnee.valNull));
  utl_file.put_line (fichierId, '    VALEURS NULL:  ' || donnee.valNull);
  utl_file.put_line (fichierId, 'VALEURS NON NULL:  ' || donnee.totVal);
  utl_file.put_line (fichierId, '   VALEURS VIDES:  ' || (valVide));
  utl_file.put_line (fichierId, '    100-QUANTILE:  ' || (donnee.quantile100));
  utl_file.put_line (fichierId, '   1000-QUANTILE:  ' || (donnee.quantile1000));

  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM TABLE(image);

  SELECT COUNT(*) INTO valVide FROM TABLE(nom) WHERE COLUMN_VALUE = '';

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'image');

  utl_file.put_line (fichierId, '             MAX:  ' || donnee.max);
  utl_file.put_line (fichierId, '             MIN:  ' || donnee.min);
  utl_file.put_line (fichierId, '         MOYENNE:  ' || ROUND(donnee.avg,2));
  utl_file.put_line (fichierId, '      ECART-TYPE:  ' || ROUND(donnee.ecart,2));
  utl_file.put_line (fichierId, '         MEDIANE:  ' || ROUND(donnee.mediane,2));
  utl_file.put_line (fichierId, '     NBR VALEURS:  ' || (donnee.totVal + donnee.valNull));
  utl_file.put_line (fichierId, '    VALEURS NULL:  ' || donnee.valNull);
  utl_file.put_line (fichierId, 'VALEURS NON NULL:  ' || donnee.totVal);
  utl_file.put_line (fichierId, '   VALEURS VIDES:  ' || (valVide));
  utl_file.put_line (fichierId, '    100-QUANTILE:  ' || (donnee.quantile100));
  utl_file.put_line (fichierId, '   1000-QUANTILE:  ' || (donnee.quantile1000));


  id.delete;
  nom.delete;
  image.delete;
  id := nestedChar();
  nom := nestedChar();
  image:= nestedChar();

  utl_file.fclose (fichierId);

EXCEPTION
  WHEN OTHERS THEN 
    IF utl_file.is_open(fichierId) THEN
     utl_file.fclose (fichierId);
    END IF;
    RAISE;

END;
/

--ListeAg et XMLAG à utiliser le1er pour la table externe et la liste des genres et ne 2eme au XML
