 USE [ITXdScience]
GO
/****** Object:  StoredProcedure [dbo].[Create_All_2]    Script Date: 27/06/2023 15:52:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Xavier Ortega
-- Create date:	15/mayo/2018
-- Description:	Creación de modelos (Proceso Rolling Average)
-- =============================================
ALTER PROCEDURE [dbo].[Create_All_2] 
	-- Add the parameters for the stored procedure here
WITH EXECUTE AS SELF
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

EXEC	[dbo].[MovTrend_UPD_GEN]

EXEC sp_execute_external_script 
    @language = N'R',
    @script = N'

# Set the number of cores to use
rxOptions(numCoresToUse = 7)

# Define the SQL connection string
sqlConnString <- "SERVER=FIN_CEN_029\\SQLEXPRESSPETERG;DATABASE=ITXdScience;Trusted_Connection=Yes;Driver=SQL Server Native Client 11.0;"

# Set the number of rows to read per iteration
sqlRowsPerRead <- 10000

# Define the input data source
sqlNewInputView <- "PreCalcModel"
sqlNewInputDS <- RxSqlServerData(connectionString = sqlConnString, table = sqlNewInputView, rowsPerRead = sqlRowsPerRead) 
XVar <- rxImport(inData = sqlNewInputDS, outFile = NULL, overwrite = TRUE)

# Define the scoring data source
sqlScoreTable <- "store_models_all"
sqlScoreDS <- RxSqlServerData(connectionString = sqlConnString, table = sqlScoreTable, rowsPerRead = sqlRowsPerRead)

# Build the formula
train_vars <- rxGetVarNames(XVar)
train_vars <- train_vars[!train_vars %in% c("Minut", 
                                            "MESSAGE_DATE_D", 
                                            "BilledFrom", 
                                            "BILLING_OPERATOR", 
                                            "RATING_SCENARIO_N_D", 
                                            "Escenario", 
                                            "minut_MA_07", 
                                            "id01", 
                                            "id02", 
                                            "id03")]

temp <- paste(c("Minut", paste(train_vars, collapse = "+")), collapse = "~")
fx <- as.formula(temp)

# Define the T_PredictFull function
T_PredictFull <- function(keys, data, formula) {
  sqlRowsPerRead <- 50000
  sqlScoreTable <- "minutes_score_test_All"
  sqlScoreDS <- RxSqlServerData(connectionString = sqlConnString, table = sqlScoreTable, rowsPerRead = sqlRowsPerRead)
  
  MO_FT_func <- rxFastTrees(
    formula = formula,
    data = data,
    minSplit = NULL,
    numTrees = NULL,
    numLeaves = NULL,
    learningRate = 0.1,
    type = "regression"
  )
  
  r_pred2 <- rxPredict(
    modelObject = MO_FT_func,
    data = rxImport(inData = data, outFile = NULL, overwrite = TRUE),
    outData = NULL,
    writeModelVars = FALSE,
    extraVarsToWrite = c("Minut", "MESSAGE_DATE_D", "Escenario"),
    overwrite = TRUE
  )
  
  r_pred2$DayWeek <- as.integer(as.POSIXlt(r_pred2$MESSAGE_DATE_D)$wday + 1)
  
  StoreModel_DS <- RxSqlServerData(connectionString = sqlConnString, 
                                   table = "store_models_all", 
                                   rowsPerRead = sqlRowsPerRead)  
  rxWriteObject(StoreModel_DS, keys, MO_FT_func)
  rxDataStep(inData = r_pred2, sqlScoreDS, append = "rows")
}

# Create the StoreModel_DS object
StoreModel_DS <- RxSqlServerData(connectionString = sqlConnString, table = "store_models_all", rowsPerRead = sqlRowsPerRead)

# Regenerate the StoreModel_DS table
ddl <- paste(
  "CREATE TABLE [", StoreModel_DS@table, "] (",
  "     [id] varchar(200) NULL, ",
  "     [value] varbinary(max)",
  ")",
  sep = ""
)

rxOpen(StoreModel_DS)  # Check Out

if (rxSqlServerTableExists(StoreModel_DS@table, StoreModel_DS@connectionString)) {
  rxSqlServerDropTable(StoreModel_DS@table, StoreModel_DS@connectionString)
}

rxExecuteSQLDDL(StoreModel_DS, sSQLString = ddl)

# Regenerate the Score_DS table
Score_DS <- RxSqlServerData(connectionString = sqlConnString, table = "minutes_score_test_All")

rxOpen(Score_DS)

if (rxSqlServerTableExists(Score_DS@table, Score_DS@connectionString)) {
  rxSqlServerDropTable(Score_DS@table, Score_DS@connectionString)
}

dd_TS <- paste(
  "CREATE TABLE [", Score_DS@table, "] (",
  "     [Score] [float] NULL, ",
  "     [Minut] [float] NULL, ",
  "     [MESSAGE_DATE_D] [date] NOT NULL,",
  "     [Escenario] [varchar](50) COLLATE Modern_Spanish_CI_AS NOT NULL,",
  "     [DayWeek] [int] NOT NULL,",
  "     CONSTRAINT [Clave_Prim_2]  PRIMARY KEY NONCLUSTERED ",
  "     (",
  "     ESCENARIO, [MESSAGE_DATE_D] DESC",
  "     )",
  "     )WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA)",
  sep = ""
)

rxExecuteSQLDDL(Score_DS, sSQLString = dd_TS)

# Execute T_PredictFull using rxExecBy
ODS_pred <- rxExecBy(
  inData = XVar,
  keys = c("Escenario"),
  func = T_PredictFull,
  filterFunc = function(x) x,
  formula = fx
)

'; -- finish R code

ALTER TABLE [dbo].[minutes_score_test_All]
	ADD INDEX minutes_score_test_bd_índice NONCLUSTERED (ESCENARIO, DayWeek, MESSAGE_DATE_D DESC);

SELECT 
ESCENARIO,
DATEADD(d, -0, MAX(MESSAGE_DATE_D)) as Fecha_Max

FROM [ITXdScience].[dbo].[minutes_score_test_All]
GROUP BY Escenario;

END