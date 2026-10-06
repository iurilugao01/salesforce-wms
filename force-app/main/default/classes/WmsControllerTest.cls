@IsTest
private class WmsControllerTest {
    @IsTest
    static void listarDepositosRetornaOrdenadoPorNome() {
        TestDataFactory.criarDeposito('Zeta');
        TestDataFactory.criarDeposito('Alfa');
        List<WmsController.OpcaoDeposito> r = WmsController.listarDepositos();
        Assert.areEqual(2, r.size());
        Assert.areEqual('Alfa', r[0].nome);
        Assert.areEqual('Zeta', r[1].nome);
    }

    @IsTest
    static void buscarHierarquiaMontaArvoreComOcupacaoELimita100() {
        Deposito__c d = TestDataFactory.criarDeposito('Dep');
        Zona__c z = TestDataFactory.criarZona(d.Id, 'Z1');
        Zona__c zVazia = TestDataFactory.criarZona(d.Id, 'Z2');
        Corredor__c c = TestDataFactory.criarCorredor(z.Id, 'C1');
        Posicao__c metade = TestDataFactory.criarPosicao(c.Id, 'P-METADE', 100);
        Posicao__c estourada = TestDataFactory.criarPosicao(c.Id, 'P-ESTOURADA', 10);
        Posicao__c semCapacidade = TestDataFactory.criarPosicao(c.Id, 'P-SEM-CAP', null);
        Produto__c prod = TestDataFactory.criarProduto('SKU-W');
        Lote__c l = TestDataFactory.criarLote(prod.Id, 'LW-1', Date.today().addDays(30));
        TestDataFactory.criarSaldo(l.Id, metade.Id, 50);
        TestDataFactory.criarSaldo(l.Id, estourada.Id, 50);
        TestDataFactory.criarSaldo(l.Id, semCapacidade.Id, 7);

        WmsController.DepositoVisao v = WmsController.buscarHierarquia(d.Id);
        Assert.areEqual(2, v.zonas.size());
        Assert.areEqual('Z1', v.zonas[0].nome);
        Assert.areEqual(0, v.zonas[1].corredores.size(), 'zona sem corredores aparece vazia');
        List<WmsController.PosicaoVisao> pos = v.zonas[0].corredores[0].posicoes;
        Map<String, WmsController.PosicaoVisao> porCodigo = new Map<String, WmsController.PosicaoVisao>();
        for (WmsController.PosicaoVisao p : pos) { porCodigo.put(p.codigo, p); }
        Assert.areEqual(50, porCodigo.get('P-METADE').percentual);
        Assert.areEqual(100, porCodigo.get('P-ESTOURADA').percentual, 'limitado a 100%');
        Assert.areEqual(0, porCodigo.get('P-SEM-CAP').percentual, 'capacidade nula: sem divisão por zero');
        Assert.areEqual(7, porCodigo.get('P-SEM-CAP').ocupado);
    }

    @IsTest
    static void buscarHierarquiaDeDepositoSemEstruturaRetornaListaVazia() {
        Deposito__c d = TestDataFactory.criarDeposito('Vazio');
        Assert.areEqual(0, WmsController.buscarHierarquia(d.Id).zonas.size());
    }

    @IsTest
    static void lotesAVencerFiltraJanelaSaldoEOrdena() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('W1-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-W2');
        Lote__c proximo = TestDataFactory.criarLote(prod.Id, 'L-PROX', Date.today().addDays(5));
        Lote__c vencido = TestDataFactory.criarLote(prod.Id, 'L-VENC', Date.today().addDays(-3));
        Lote__c longe = TestDataFactory.criarLote(prod.Id, 'L-LONGE', Date.today().addDays(200));
        Lote__c semSaldo = TestDataFactory.criarLote(prod.Id, 'L-ZERO', Date.today().addDays(4));
        Lote__c semValidade = TestDataFactory.criarLote(prod.Id, 'L-SEMVAL', null);
        for (Lote__c l : new List<Lote__c>{ proximo, vencido, longe, semValidade }) {
            TestDataFactory.criarSaldo(l.Id, pos.Id, 10);
        }
        TestDataFactory.criarSaldo(semSaldo.Id, pos.Id, 0);

        List<WmsController.LoteAlerta> r = WmsController.lotesAVencer(30);
        Assert.areEqual(2, r.size());
        Assert.areEqual('L-VENC', r[0].numeroLote);
        Assert.areEqual(-3, r[0].diasRestantes);
        Assert.areEqual('L-PROX', r[1].numeroLote);
        Assert.areEqual(5, r[1].diasRestantes);
        Assert.areEqual(10, r[1].saldoTotal);
        Assert.areEqual(prod.Name, r[1].produto);
        Assert.areEqual(2, WmsController.lotesAVencer(null).size(), 'null equivale a 30 dias');
    }

    @IsTest
    static void lotesDisponiveisEmOrdemFefoSemVencidosNemZerados() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('W2-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-W3');
        Lote__c longe = TestDataFactory.criarLote(prod.Id, 'L-LONGE', Date.today().addDays(90));
        Lote__c perto = TestDataFactory.criarLote(prod.Id, 'L-PERTO', Date.today().addDays(10));
        Lote__c vencido = TestDataFactory.criarLote(prod.Id, 'L-VENC', Date.today().addDays(-1));
        Lote__c zerado = TestDataFactory.criarLote(prod.Id, 'L-ZERO', Date.today().addDays(20));
        TestDataFactory.criarSaldo(longe.Id, pos.Id, 5);
        TestDataFactory.criarSaldo(perto.Id, pos.Id, 7);
        TestDataFactory.criarSaldo(vencido.Id, pos.Id, 9);
        TestDataFactory.criarSaldo(zerado.Id, pos.Id, 0);

        List<WmsController.LoteOpcao> r = WmsController.lotesDisponiveis(prod.Id, pos.Id);
        Assert.areEqual(2, r.size());
        Assert.areEqual(perto.Id, r[0].loteId);
        Assert.isTrue(r[0].rotulo.contains('L-PERTO'));
        Assert.areEqual(7, r[0].saldo);
        Assert.areEqual(longe.Id, r[1].loteId);
    }

    @IsTest
    static void registrarMovimentacaoGravaESaldoReflete() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('W3-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-W4');
        Lote__c l = TestDataFactory.criarLote(prod.Id, 'L-REG', Date.today().addDays(30));
        Id id = WmsController.registrarMovimentacao(MovimentacaoTipo.ENTRADA, l.Id, null, pos.Id, 12);
        Assert.isNotNull(id);
        Assert.areEqual(12, TestDataFactory.saldo(l.Id, pos.Id));
    }

    @IsTest
    static void registrarMovimentacaoInvalidaViraAuraHandledExceptionComMensagemDeNegocio() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('W4-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-W5');
        Lote__c l = TestDataFactory.criarLote(prod.Id, 'L-ERR', Date.today().addDays(30));
        try {
            WmsController.registrarMovimentacao(MovimentacaoTipo.SAIDA, l.Id, pos.Id, null, 10);
            Assert.fail('deveria lançar AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Saldo insuficiente'), 'mensagem real: ' + e.getMessage());
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Log_Erro__c], 'erro de negócio não vai para o log');
    }
}
