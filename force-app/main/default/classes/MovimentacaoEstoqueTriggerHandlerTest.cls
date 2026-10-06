@IsTest
private class MovimentacaoEstoqueTriggerHandlerTest {
    private static Posicao__c p1;
    private static Posicao__c p2;
    private static Lote__c lote;

    private static void montar() {
        p1 = TestDataFactory.criarPosicaoCompleta('T1-01');
        p2 = TestDataFactory.criarPosicaoCompleta('T1-02');
        Produto__c prod = TestDataFactory.criarProduto('SKU-T');
        lote = TestDataFactory.criarLote(prod.Id, 'LT-001', Date.today().addDays(60));
    }

    @IsTest
    static void entradaCriaSaldoEPreencheDefaults() {
        montar();
        Movimentacao_Estoque__c m = TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 100);
        Assert.areEqual(100, TestDataFactory.saldo(lote.Id, p1.Id));
        Movimentacao_Estoque__c gravada = [
            SELECT Data_Hora__c, Usuario_Responsavel__c, Status__c FROM Movimentacao_Estoque__c WHERE Id = :m.Id
        ];
        Assert.isNotNull(gravada.Data_Hora__c);
        Assert.areEqual(UserInfo.getUserId(), gravada.Usuario_Responsavel__c);
        Assert.areEqual('Concluida', gravada.Status__c);
    }

    @IsTest
    static void dataHoraEResponsavelSaoSempreDefinidosPeloSistema() {
        montar();
        User outro = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() AND IsActive = true LIMIT 1];
        Movimentacao_Estoque__c m = TestDataFactory.novaMovimentacao(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 5);
        m.Data_Hora__c = System.now().addDays(-30);
        m.Usuario_Responsavel__c = outro.Id;
        insert m;
        Movimentacao_Estoque__c gravada = [
            SELECT Data_Hora__c, Usuario_Responsavel__c FROM Movimentacao_Estoque__c WHERE Id = :m.Id
        ];
        Assert.areEqual(UserInfo.getUserId(), gravada.Usuario_Responsavel__c, 'responsável não pode ser forjado');
        Assert.isTrue(gravada.Data_Hora__c > System.now().addMinutes(-5), 'data/hora não pode ser retroativa');
    }

    @IsTest
    static void saidaDecrementaESaldoFinalCorreto() {
        montar();
        TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 100);
        TestDataFactory.registrar(MovimentacaoTipo.SAIDA, lote.Id, p1.Id, null, 40);
        Assert.areEqual(60, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void transferenciaMoveSaldoAtomicamente() {
        montar();
        TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 100);
        TestDataFactory.registrar(MovimentacaoTipo.TRANSFERENCIA, lote.Id, p1.Id, p2.Id, 25);
        Assert.areEqual(75, TestDataFactory.saldo(lote.Id, p1.Id));
        Assert.areEqual(25, TestDataFactory.saldo(lote.Id, p2.Id));
    }

    @IsTest
    static void saidaAcimaDoSaldoFalhaSemAlterarSaldo() {
        montar();
        TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 10);
        Movimentacao_Estoque__c m = TestDataFactory.novaMovimentacao(MovimentacaoTipo.SAIDA, lote.Id, p1.Id, null, 11);
        Database.SaveResult r = Database.insert(m, false);
        Assert.isFalse(r.isSuccess());
        Assert.isTrue(r.getErrors()[0].getMessage().contains('Saldo insuficiente'));
        Assert.areEqual(10, TestDataFactory.saldo(lote.Id, p1.Id));
        Assert.areEqual(1, [SELECT COUNT() FROM Movimentacao_Estoque__c]);
    }

    @IsTest
    static void movimentacaoEImutavelParaUpdateEDelete() {
        montar();
        Movimentacao_Estoque__c m = TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 10);
        m.Quantidade__c = 999;
        Database.SaveResult upd = Database.update(m, false);
        Assert.isFalse(upd.isSuccess());
        Assert.isTrue(upd.getErrors()[0].getMessage().contains('imutáveis'));
        Database.DeleteResult del = Database.delete(m.Id, false);
        Assert.isFalse(del.isSuccess());
        Assert.isTrue(del.getErrors()[0].getMessage().contains('imutáveis'));
        Assert.areEqual(10, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void duzentasEntradasNumUnicoDmlSaoAgregadas() {
        montar();
        List<Movimentacao_Estoque__c> lista = new List<Movimentacao_Estoque__c>();
        for (Integer i = 0; i < 200; i++) {
            lista.add(TestDataFactory.novaMovimentacao(MovimentacaoTipo.ENTRADA, lote.Id, null, p1.Id, 1));
        }
        insert lista;
        Assert.areEqual(200, TestDataFactory.saldo(lote.Id, p1.Id));
    }

    @IsTest
    static void duzentasSaidasComSaldoCemSucessoParcialAplicaApenasCem() {
        montar();
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 100);
        List<Movimentacao_Estoque__c> lista = new List<Movimentacao_Estoque__c>();
        for (Integer i = 0; i < 200; i++) {
            lista.add(TestDataFactory.novaMovimentacao(MovimentacaoTipo.SAIDA, lote.Id, p1.Id, null, 1));
        }
        List<Database.SaveResult> resultados = Database.insert(lista, false);
        Integer sucessos = 0;
        for (Database.SaveResult r : resultados) {
            if (r.isSuccess()) { sucessos++; }
        }
        Assert.areEqual(100, sucessos);
        Assert.areEqual(0, TestDataFactory.saldo(lote.Id, p1.Id));
    }
}
