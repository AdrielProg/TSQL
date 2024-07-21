CREATE OR ALTER PROCEDURE [dbo].[SP_ListarDezProdutosMenosVendidosEmDadoMes]
    @Ano INT,
    @Mes INT
AS 
/*
    Documentacao
    Arquivo Fonte...: SP_ListarProdutosMenosVendidosEmDadoMesAdriel.sql
    Objetivo........: Listar 10 Produtos Menos Vendidos em um determinado mes e ano com base nas vendas realizadas com o total
                      Do que foi vendido ao mês vigente, anterior e anterior ao anterior. Ainda Faz a média mensal das vendas do
                      ano vigente e do ano anterior para os 10 produtos menos vendidos  
    Autor...........: Adriel Alexander de Sousa
    Data............: 06/06/2024
    Autor Alteracao.: Adriel Alexander
    Data Alteracao..: 07/06/2024
    Exemplo.........: DBCC DROPCLEANBUFFERS
                      DBCC FREEPROCCACHE

                        DECLARE @DataInicio DATETIME = GETDATE(),   
                                @RET INT

                        EXEC @RET = [dbo].[SP_ListarDezProdutosMenosVendidosEmDadoMes] 2022, 01;

                        SELECT DATEDIFF(MILLISECOND, @DataInicio, GETDATE()) AS TempoExecucao,
                                @RET AS Retorno

    Retornos.........: 0 - Sucesso,   
                       1 - Error: Deve ser passado um mês valido para processamento de dados     
                       2 - Error: O ano passado por parâmentro não pode ser maior que o ano atual ou nulo
*/
    BEGIN 
        -- Declarando variaveis pertinentes ao processamento
        DECLARE @DataProcessamento DATE,
                @DataProcessamentoFim DATE,
                @AnoAnterior INT


        -- Validacao do Mes, passado por parametro
        IF  @Mes > 12 OR @Mes <1 OR @Mes IS NULL
            BEGIN
                RETURN 1
            END

        -- Validacao do Ano, passado por parametro
        IF @Ano > YEAR(GETDATE()) OR @Ano IS NULL
            BEGIN
                RETURN 2
            END;

        -- Atribui valor a data do mês/ano passado como parametro e calcular os valores de mes e anos anteriores
        SELECT  @DataProcessamento = DATEADD(DAY,-1,DATEFROMPARTS(ABS(@Ano), ABS(@Mes + 1), 1)),
		        @AnoAnterior = YEAR(DATEADD(YEAR, -1, @DataProcessamento)),
                @DataProcessamentoFim = DATEADD(DAY, 1, EOMONTH(DATEADD(MONTH, -4, @DataProcessamento)));
        
		--seleciona os 12 meses para cada idProduto para calcular a media anual com base nos meses
        WITH VendasPorPeriodoMes AS 
			(
				SELECT	pp.IdProduto,
						SUM(CASE WHEN YEAR(p.DataPedido) = @Ano AND MONTH(p.DataPedido) = @Mes 
								    THEN pp.Quantidade 
									ELSE 0 
							END) AS QuantidadeVendidaNoMes,
						SUM(CASE WHEN DATEDIFF(MONTH, p.DataPedido, @DataProcessamento) = 1
									THEN pp.Quantidade 
									ELSE 0 
							END) AS QuantidadeVendidaMesAnterior,
						SUM(CASE WHEN DATEDIFF(MONTH, p.DataPedido, @DataProcessamento) = 2
									THEN pp.Quantidade 
									ELSE 0 
							END) AS QuantidadeVendidaMesAnteriorAoAnterior,
                        SUM(CASE WHEN YEAR(p.DataPedido) = @Ano 
                                THEN pp.Quantidade 
                                ELSE 0 
                        END)/12 AS SomaQuantidadeVendidaPorMesAnoAtual,
                        SUM(CASE WHEN YEAR(p.DataPedido) = @AnoAnterior
                                THEN pp.Quantidade 
                                ELSE 0 
                        END)/12 AS SomaQuantidadeVendidaPorMesAnoAnterior
					FROM [dbo].[PedidoProduto] pp WITH(NOLOCK)
						INNER JOIN [dbo].[Pedido] p WITH(NOLOCK)
							ON pp.IdPedido = p.Id
                     WHERE YEAR(p.DataPedido) = @Ano
                        OR YEAR (p.DataPedido) = @AnoAnterior
						GROUP BY pp.IdProduto
            )
            -- Seleciona os top 10 produtos menos vendidos ordenados pelo rank asc e faz a média das vendas do ano por mês
            SELECT TOP 10   p.Id AS CodigoProduto,
                            p.Nome AS NomeProduto, 
                            vpp.QuantidadeVendidaNoMes,
                            vpp.QuantidadeVendidaMesAnterior,
                            vpp.QuantidadeVendidaMesAnteriorAoAnterior,
                            vmp.SomaQuantidadeVendidaPorMesAnoAtual AS QuantidadeMediaDeVendaNoAnoCorrente,
                            vmp.SomaQuantidadeVendidaPorMesAnoAnterior AS QuantidadeMediaDeVendaNoAnoPassado
                FROM [dbo].[Produto] p WITH(NOLOCK)
                    INNER JOIN [VendasPorPeriodoMes]vpp
                        ON vpp.IdProduto = p.id
                    INNER JOIN [VendasMensalPorAnoProcessamento] vmp
                        ON vmp.IdProduto = p.id
                ORDER BY vpp.QuantidadeVendidaNoMes
        RETURN 0
    END
GO