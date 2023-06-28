USE [ITXdScience]
GO

/****** Object:  Table [dbo].[store_models_all]    Script Date: 28/06/2023 9:05:58 ******/
DROP TABLE [dbo].[store_models_all]
GO

/****** Object:  Table [dbo].[store_models_all]    Script Date: 28/06/2023 9:05:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[store_models_all](
	[id] [varchar](200) NULL,
	[value] [varbinary](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


