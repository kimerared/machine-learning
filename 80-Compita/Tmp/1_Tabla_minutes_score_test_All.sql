USE [ITXdScience]
GO

/****** Object:  Table [dbo].[minutes_score_test_All]    Script Date: 28/06/2023 9:04:28 ******/
DROP TABLE [dbo].[minutes_score_test_All]
GO

/****** Object:  Table [dbo].[minutes_score_test_All]    Script Date: 28/06/2023 9:04:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[minutes_score_test_All]
(
	[Score] [float] NULL,
	[Minut] [float] NULL,
	[MESSAGE_DATE_D] [date] NOT NULL,
	[Escenario] [varchar](50) COLLATE Modern_Spanish_CI_AS NOT NULL,
	[DayWeek] [int] NOT NULL,

 CONSTRAINT [Clave_Prim_2]  PRIMARY KEY NONCLUSTERED 
(
	[Escenario] ASC,
	[MESSAGE_DATE_D] DESC
),
INDEX [minutes_score_test_bd_índice] NONCLUSTERED 
(
	[Escenario] ASC,
	[DayWeek] ASC,
	[MESSAGE_DATE_D] DESC
)
)WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA )
GO


