Folder used to store custom SQL files that will be executed as part of the Kie Server installation.

**Notes**:
* All "*.sql" files will be executed in unpredictable order
* If any ordering is needed, aggregate the dependant files in a single file 
* The SQL language used must be compliant with the DB type specified in [installer.properties](../../../installer.properties) as `DB_TYPE` 