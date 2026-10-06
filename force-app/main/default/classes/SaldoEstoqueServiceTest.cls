@IsTest
private class SaldoEstoqueServiceTest {
    private static Posicao__c p1;
    private static Posicao__c p2;
    private static Lote__c lote;

    private static void montar() {
        p1 = TestDataFactory.criarPosicaoCompleta('A1-01');
        p2 = TestDataFactory.criarPosicaoCompleta('A1-02');
        Produto__c prod = TestDataFactory.criarProduto('SKU-1');
        lote = TestDataFactory.criarLote(prod.Id, 'L-001', Date.today().addDays(60));
    }

    private static Movimentacao_Estoque__c mov(String tipo, Id origem, Id destino, Decimal qtd) {
        return TestDataFactory.novaMovimentacao(tipo, lote.Id, origem, destino, qtd);
    }

    @IsTest
    static void chaveCombinaLoteEPosicao() {
        montar();
        String chave = SaldoEstoqueService.chave(lote.Id, p1.Id);
        Assert.areEqual(String.valueOf(lote.Id) + '-' + String.valueOf(p1.Id), chave);
        Assert.areEqual(37, chave.length());
    }

    @IsTest
    static void entradaCriaSaldoNoDestino() {
        montar();
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{
            mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 100)
        });
        Assert.areEqual(100, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void entradaSomaAoSaldoExistente() {
        montar();
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 100) });
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 30) });
        Assert.areEqual(130, TestDataFactory.saldo(lote.Id, p1.Id));
        Assert.areEqual(1, [SELECT COUNT() FROM Saldo_Estoque__c WHERE Lote__c = :lote.Id AND Posicao__c = :p1.Id]);
    }

    @IsTest
    static void saidaDecrementaOrigem() {
        montar();
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 100) });
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.SAIDA, p1.Id, null, 40) });
        Assert.areEqual(60, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void transferenciaMoveEntrePosicoes() {
        montar();
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 100) });
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.TRANSFERENCIA, p1.Id, p2.Id, 35) });
        Assert.areEqual(65, TestDataFactory.saldo(lote.Id, p1.Id));
        Assert.areEqual(35, TestDataFactory.saldo(lote.Id, p2.Id));
    }

    @IsTest
    static void saldoNegativoLancaExcecaoENaoGrava() {
        montar();
        SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{ mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 10) });
        try {
            SaldoEstoqueService.aplicar(new List<Movimentacao_Estoque__c>{
                mov(MovimentacaoTipo.SAIDA, p1.Id, null, 11)
            });
            Assert.fail('deveria lançar SaldoInsuficienteException');
        } catch (SaldoEstoqueService.SaldoInsuficienteException e) {
            Assert.isTrue(e.getMessage().contains('Saldo insuficiente'));
        }
        Assert.areEqual(10, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void duzentasEntradasViramUmaUnicaOperacao() {
        montar();
        List<Movimentacao_Estoque__c> lista = new List<Movimentacao_Estoque__c>();
        for (Integer i = 0; i < 200; i++) {
            lista.add(mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 1));
        }
        Integer queriesAntes = Limits.getQueries();
        Integer dmlAntes = Limits.getDmlStatements();
        SaldoEstoqueService.aplicar(lista);
        Assert.areEqual(1, Limits.getQueries() - queriesAntes, 'uma única consulta de saldos');
        Assert.areEqual(1, Limits.getDmlStatements() - dmlAntes, 'um único upsert');
        Assert.areEqual(200, TestDataFactory.saldo(lote.Id, p1.Id));
    }
}
