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

  --Type contenant les résultats de la requête
  TYPE result IS RECORD
  (
    max NUMBER,
    min NUMBER,
    avg NUMBER,
    ecart NUMBER,
    mediane NUMBER,
    totVal NUMBER,
    quantile100 NUMBER,
    quantile10000 NUMBER,
    valNull NUMBER
  );
  donnee result;

  valVide NUMBER;

  cpt NUMBER;
  parc NUMBER;
  i NUMBER;
  j NUMBER;

  TYPE resultChain IS TABLE OF varchar2(4000) INDEX BY BINARY_INTEGER;
  valeursUniques resultChain;
  chaineRegex resultChain;

  id nestedChar := nestedChar();
  nom nestedChar := nestedChar();
  image nestedChar := nestedChar();
  idPerso nestedChar := nestedChar();
  nomPerso nestedChar := nestedChar();

  --Colonne composée ayant seulement deux champs pour chaque tuple (id et nom)
  listeColonne2Champs nestedChar := nestedChar('GENRES', 'PRODUCTION_COMPANIES', 'PRODUCTION_COUNTRIES', 'SPOKEN_LANGUAGES');

  requeteBlock varchar2(500);
  morceauRecup varchar2(10000);
  tmpChaine varchar2(10000);

  resultParse OWA_TEXT.VC_ARR;
  
BEGIN
  --Creation d'un fichier dans le directory pour contenir le rapport
  fichierId := utl_file.fopen ('MOVIEDIRECTORY', 'Rapport.txt', 'W');
  --Ecriture d'un titre
  utl_file.put_line (fichierId, 'RAPPORT FILM');
  utl_file.put_line (fichierId, '------------');

  /*J'enregistre dans un tableau le nom et le type des colonnes simple (celle pour lesquels il n'y a qu'une seule valeur et pas une chaine de 
     valeurs au format [... ,, ... || ... ,, ...])*/
  SELECT COLUMN_NAME, DATA_TYPE BULK COLLECT INTO nomColonne 
  FROM user_tab_columns 
  WHERE table_name='MOVIES_EXT'
  AND COLUMN_NAME != 'GENRES'
  AND COLUMN_NAME != 'DIRECTORS'
  AND COLUMN_NAME != 'ACTORS'
  AND COLUMN_NAME != 'PRODUCTION_COMPANIES'
  AND COLUMN_NAME != 'PRODUCTION_COUNTRIES'
  AND COLUMN_NAME != 'SPOKEN_LANGUAGES';

  utl_file.put_line (fichierId, 'TABLE FILM : ');

  --Pour chaque colonne simple :
  FOR cpt IN nomColonne.FIRST..nomColonne.LAST LOOP

    utl_file.put_line (fichierId,'');
    utl_file.put_line (fichierId, nomColonne(cpt).nom || ' :');
    --Creation de la requete statistique à exécuter en utilisant le nom de la colonne contenu dans le tableau nomColonne
    requeteBlock := 'SELECT MAX(LENGTH('||nomColonne(cpt).nom ||')), MIN(LENGTH('||nomColonne(cpt).nom ||')), 
    AVG(LENGTH('||nomColonne(cpt).nom ||')), STDDEV(LENGTH('||nomColonne(cpt).nom ||')), 
    MEDIAN(LENGTH('||nomColonne(cpt).nom ||')), COUNT('||nomColonne(cpt).nom ||'), 
    PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH('||nomColonne(cpt).nom ||')), 
    PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH('||nomColonne(cpt).nom ||')), 
    COUNT(NVL2('||nomColonne(cpt).nom||', NULL, 1))
    FROM MOVIES_EXT';
    --exécution de la requete et récupération du résultat
    EXECUTE IMMEDIATE (requeteBlock) INTO donnee;

    --Requete pour les champs vide selon le type (number champ vide = 0, varchar champ vide = '')
    IF(nomColonne(cpt).type = 'NUMBER') THEN
      requeteBlock := 'SELECT COUNT(*) FROM MOVIES_EXT WHERE ' || nomColonne(cpt).nom || ' = 0';
    ELSE
      requeteBlock := 'SELECT COUNT(*) FROM MOVIES_EXT WHERE ' || nomColonne(cpt).nom || ' = '''' ';
    END IF;

    EXECUTE IMMEDIATE (requeteBlock) INTO valVide;
    --Ecriture des résultats dans le fichier rapport.txt
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
    utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

    --traitement des colonnes dont on veut connaitre les valeurs unique (lorsque celles-ci sont peut nombreuses)
    IF(nomColonne(cpt).nom = 'STATUS' OR nomColonne(cpt).nom = 'CERTIFICATION') THEN

      requeteBlock := 'SELECT DISTINCT '|| nomColonne(cpt).nom || ' FROM MOVIES_EXT';
      EXECUTE IMMEDIATE(requeteBlock) BULK COLLECT INTO valeursUniques;

      utl_file.put_line(fichierId,'NOMBRE VALEURS UNIQUES : ' || valeursUniques.COUNT);
      utl_file.put_line(fichierId,'               VALEURS : ');

      FOR i IN valeursUniques.FIRST..valeursUniques.LAST LOOP
        utl_file.put_line(fichierId,'                      ' || valeursUniques(i));
      END LOOP;

      valeursUniques.DELETE;
    END IF;

  END LOOP;


  /*******************FIN DES COLONNES SIMPLE DEBUT DES COLONNES COMPOSEES****************/

  --Colonnes à 2 champs par tuple
  parc := listeColonne2Champs.FIRST;

  WHILE parc IS NOT NULL LOOP

    utl_file.put_line (fichierId, '');
    utl_file.put_line (fichierId, listeColonne2Champs(parc));

    i:=1;
    --On recupere dans une variable la chaine à décomposer.
    requeteBlock := 'SELECT regexp_substr(' ||listeColonne2Champs(parc) ||', ''^\[\[(.*)\]\]$'', 1, 1, '''', 1) FROM movies_ext';
    EXECUTE IMMEDIATE requeteBlock BULK COLLECT INTO chaineRegex;

    FOR cpt IN chaineRegex.FIRST..chaineRegex.LAST LOOP
      IF(LENGTH(chaineRegex(cpt)) > 0) THEN
        LOOP
          --Recuperation d'un tuple. Chaque tuple est séparé par des ||.
          morceauRecup := regexp_substr(chaineRegex(cpt), '(.*?)(\|\||$)', 1, i, '', 1);
          EXIT WHEN morceauRecup IS NULL;

          j:=1;
          LOOP
            --On décompose le tuple récupéré (chaque champs d'un tuple est séparé par ,, ou ,,,)
            tmpChaine:=regexp_substr(morceauRecup, '(.*?)(,{2,}|$)', 1, j, '', 1);
            EXIT WHEN tmpChaine IS NULL;
            --On enregistre chaque tuple dans un tableau
            IF j=1 THEN
              id.extend();
              nom.extend();
              id(id.COUNT):=tmpChaine;
            ELSIF j=2 THEN
              nom(nom.COUNT):=tmpChaine;
              EXIT;
            END IF;
            j:=j+1;
          END LOOP;
          i:= i + 1;
        END LOOP;
        i:= 1;
      END IF;
    END LOOP;

    --Requete permettant le calcul statistique sur les tableaux remplis. (ici l'ID)
    SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
    MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
    PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
    FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id));

    SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id)) WHERE COLUMN_VALUE = '';

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
    utl_file.put_line (fichierId, '  10000-QUANTILE:  ' || (donnee.quantile10000));

    --Requete permettant le calcul statistique sur les tableaux remplis. (ici len nom)
    SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
    MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
    PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
    FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom));

    SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom)) WHERE COLUMN_VALUE = '';

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
    utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

    id.delete;
    nom.delete;
    id := nestedChar();
    nom := nestedChar();

    parc := listeColonne2Champs.NEXT(parc);
  END LOOP;

  --FIN DES COLONNE AVEC DES TUPLES COMPOSES DE DEUX CHAMPS

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'DIRECTORS');
  --Traitement de la colonne directors (3 champs par tuples)
  i:=1;
  SELECT regexp_substr(DIRECTORS , '^\[\[(.*)\]\]$', 1, 1, '', 1) BULK COLLECT INTO chaineRegex FROM movies_ext;

  FOR cpt IN chaineRegex.FIRST..chaineRegex.LAST LOOP
    IF(LENGTH(chaineRegex(cpt)) > 0) THEN
      LOOP
        morceauRecup := regexp_substr(chaineRegex(cpt), '(.*?)(\|\||$)', 1, i, '', 1);
        EXIT WHEN morceauRecup IS NULL;

        j:=1;
        LOOP
          tmpChaine:=regexp_substr(morceauRecup, '(.*?)(,{2,}|$)', 1, j, '', 1);
          EXIT WHEN tmpChaine IS NULL;

          IF j=1 THEN
            id.extend();
            nom.extend();
            image.extend();
            id(id.COUNT):=tmpChaine;
          ELSIF j=2 THEN
            nom(nom.COUNT):=tmpChaine;
          ELSIF j=3 THEN
            image(image.COUNT):=tmpChaine;
            EXIT;
          END IF;
          j:=j+1;

        END LOOP;
        i:= i + 1;
      END LOOP;
      i:= 1;
    END IF;
  END LOOP;

--Requete permettant le calcul statistique sur les tableaux remplis. (ici l'ID)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

--Requete permettant le calcul statistique sur les tableaux remplis. (ici le nom)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));


  --Requete permettant le calcul statistique sur les tableaux remplis. (ici l'image)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(image));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(image)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));


  id.delete;
  nom.delete;
  image.delete;
  id := nestedChar();
  nom := nestedChar();
  image:= nestedChar();

  --FIN DIRECTORS
  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'ACTORS');


  --PARSING DES ACTEURS (5 champs par tuples)
  i:=1;
    SELECT regexp_substr(actors, '^\[\[(.*)\]\]$', 1, 1, '', 1) BULK COLLECT INTO chaineRegex FROM movies_ext;

    FOR cpt IN chaineRegex.FIRST..chaineRegex.LAST LOOP
   
    IF(LENGTH(chaineRegex(cpt)) > 0) THEN
     
      LOOP
        morceauRecup := regexp_substr(chaineRegex(cpt), '(.*?)(\|\||$)', 1, i, '', 1);
        EXIT WHEN morceauRecup IS NULL;
        j:=1;
        LOOP
          tmpChaine:=regexp_substr(morceauRecup, '(.*?)(,{2,}|$)', 1, j, '', 1);
          EXIT WHEN tmpChaine IS NULL;

          IF j=1 THEN
            id.extend();
            nom.extend();
            image.extend();
            idPerso.extend();
            nomPerso.extend();
            id(id.COUNT):=tmpChaine;
          ELSIF j=2 THEN
            nom(nom.COUNT):=tmpChaine;
          ELSIF j=3 THEN
            idPerso(idPerso.COUNT):=tmpChaine;
          ELSIF j=4 THEN
            nomPerso(nomPerso.COUNT):= tmpChaine;
          ELSIF j=5 THEN
            image(image.COUNT):=tmpChaine;
            EXIT;
          END IF;
 
          j:=j+1;
 
        END LOOP;
        i := i+1;
      END LOOP;
      i := 1;
    END IF;
  END LOOP;
  --Requete permettant le calcul statistique sur les tableaux remplis. (ici l'ID)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(id)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));
  --Requete permettant le calcul statistique sur les tableaux remplis. (ici le nom)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nom)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

  --Requete permettant le calcul statistique sur les tableaux remplis. (ici l'image)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(image));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(image)) WHERE COLUMN_VALUE = '';

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

  --Requete permettant le calcul statistique sur les tableaux remplis. (ici l'ID du personnages interprèté)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM TABLE(idPerso);

  SELECT COUNT(*) INTO valVide FROM TABLE(idPerso) WHERE COLUMN_VALUE = '';

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'id personnage');

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));

  --Requete permettant le calcul statistique sur les tableaux remplis. (ici le nom du personnage interprèté)
  SELECT MAX(LENGTH(COLUMN_VALUE)), MIN(LENGTH(COLUMN_VALUE)), AVG(LENGTH(COLUMN_VALUE)), STDDEV(LENGTH(COLUMN_VALUE)), 
  MEDIAN(LENGTH(COLUMN_VALUE)), COUNT(COLUMN_VALUE), PERCENTILE_CONT(0.99) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), 
  PERCENTILE_CONT(0.9999) WITHIN GROUP(ORDER BY LENGTH(COLUMN_VALUE)), COUNT(NVL2(COLUMN_VALUE, NULL, 1)) INTO donnee
  FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nomPerso));

  SELECT COUNT(*) INTO valVide FROM (SELECT DISTINCT COLUMN_VALUE FROM TABLE(nomPerso)) WHERE COLUMN_VALUE = '';

  utl_file.put_line (fichierId, '');
  utl_file.put_line (fichierId, 'nom personnage');

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
  utl_file.put_line (fichierId, '   10000-QUANTILE:  ' || (donnee.quantile10000));


  --Fin du rapport fermeture du fichier
  utl_file.fclose (fichierId);

EXCEPTION
  WHEN OTHERS THEN 
    IF utl_file.is_open(fichierId) THEN
     utl_file.fclose (fichierId);
     LOGEVENT('script rapport', SQLERRM);
    END IF;
    RAISE;

END;
/



