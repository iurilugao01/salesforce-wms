@IsTest
private class MovimentacaoValidatorTest {
    private static Posicao__c p1;
    private static Posicao__c p2;
    private static Lote__c lote;

    private static void montar() {
        p1 = TestDataFactory.criarPosicaoCompleta('V1-01');
        p2 = TestDataFactory.criarPosicaoCompleta('V1-02');
        Produto__c prod = TestDataFactory.criarProduto('SKU-V');
        lote = TestDataFactory.criarLote(prod.Id, 'LV-001', Date.today().addDays(60));
    }

    private static Movimentacao_Estoque__c mov(String tipo, Id origem, Id destino, Decimal qtd) {
        return TestDataFactory.novaMovimentacao(tipo, lote.Id, origem, destino, qtd);
    }

    private static void assertErro(Movimentacao_Estoque__c m, String trecho) {
        Assert.isTrue(m.hasErrors(), 'esperava erro contendo: ' + trecho);
        Assert.isTrue(m.getErrors()[0].getMessage().contains(trecho), 'mensagem real: ' + m.getErrors()[0].getMessage());
    }

    @IsTest
    static void entradaValidaNaoTemErro() {
        montar();
        Movimentacao_Estoque__c m = mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 10);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ m });
        Assert.isFalse(m.hasErrors());
    }

    @IsTest
    static void quantidadeZeroNegativaOuNulaERejeitada() {
        montar();
        Movimentacao_Estoque__c zero = mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 0);
        Movimentacao_Estoque__c negativa = mov(MovimentacaoTipo.ENTRADA, null, p1.Id, -5);
        Movimentacao_Estoque__c nula = mov(MovimentacaoTipo.ENTRADA, null, p1.Id, null);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ zero, negativa, nula });
        assertErro(zero, 'maior que zero');
        assertErro(negativa, 'maior que zero');
        assertErro(nula, 'maior que zero');
    }

    @IsTest
    static void posicoesIncompativeisComOTipoSaoRejeitadas() {
        montar();
        Movimentacao_Estoque__c entradaComOrigem = mov(MovimentacaoTipo.ENTRADA, p1.Id, p2.Id, 1);
        Movimentacao_Estoque__c entradaSemDestino = mov(MovimentacaoTipo.ENTRADA, null, null, 1);
        Movimentacao_Estoque__c saidaSemOrigem = mov(MovimentacaoTipo.SAIDA, null, null, 1);
        Movimentacao_Estoque__c saidaComDestino = mov(MovimentacaoTipo.SAIDA, p1.Id, p2.Id, 1);
        Movimentacao_Estoque__c transfSemDestino = mov(MovimentacaoTipo.TRANSFERENCIA, p1.Id, null, 1);
        Movimentacao_Estoque__c tipoInvalido = mov('Inventario', p1.Id, p2.Id, 1);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{
            entradaComOrigem, entradaSemDestino, saidaSemOrigem, saidaComDestino, transfSemDestino, tipoInvalido
        });
        assertErro(entradaComOrigem, 'não deve ter posição de origem');
        assertErro(entradaSemDestino, 'exige posição de destino');
        assertErro(saidaSemOrigem, 'exige posição de origem');
        assertErro(saidaComDestino, 'não deve ter posição de destino');
        assertErro(transfSemDestino, 'exige posição de destino');
        assertErro(tipoInvalido, 'Tipo de movimentação inválido');
    }

    @IsTest
    static void transferenciaParaAMesmaPosicaoERejeitada() {
        montar();
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 50);
        Movimentacao_Estoque__c m = mov(MovimentacaoTipo.TRANSFERENCIA, p1.Id, p1.Id, 5);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ m });
        assertErro(m, 'origem e destino devem ser diferentes');
    }

    @IsTest
    static void saidaAcimaDoSaldoERejeitadaEIgualAoSaldoEAceita() {
        montar();
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 50);
        Movimentacao_Estoque__c acima = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 50.01);
        Movimentacao_Estoque__c exata = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 50);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ acima });
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ exata });
        assertErro(acima, 'Saldo insuficiente');
        Assert.isFalse(exata.hasErrors());
    }

    @IsTest
    static void saidaSemNenhumSaldoERejeitada() {
        montar();
        Movimentacao_Estoque__c m = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 1);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ m });
        assertErro(m, 'Saldo insuficiente');
    }

    @IsTest
    static void loteVencidoERejeitadoMasLoteSemValidadeEAceito() {
        montar();
        Produto__c prod = TestDataFactory.criarProduto('SKU-V2');
        Lote__c vencido = TestDataFactory.criarLote(prod.Id, 'LV-VENCIDO', Date.today().addDays(-1));
        Lote__c semValidade = TestDataFactory.criarLote(prod.Id, 'LV-SEM', null);
        Movimentacao_Estoque__c mVencido = TestDataFactory.novaMovimentacao(MovimentacaoTipo.ENTRADA, vencido.Id, null, p1.Id, 1);
        Movimentacao_Estoque__c mSem = TestDataFactory.novaMovimentacao(MovimentacaoTipo.ENTRADA, semValidade.Id, null, p1.Id, 1);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ mVencido, mSem });
        assertErro(mVencido, 'vencido');
        Assert.isFalse(mSem.hasErrors(), 'lote sem validade nunca é considerado vencido');
    }

    @IsTest
    static void posicaoInativaERejeitada() {
        montar();
        p2.Ativa__c = false;
        update p2;
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 10);
        Movimentacao_Estoque__c paraInativa = mov(MovimentacaoTipo.ENTRADA, null, p2.Id, 1);
        Movimentacao_Estoque__c deInativa = mov(MovimentacaoTipo.SAIDA, p2.Id, null, 1);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ paraInativa, deInativa });
        assertErro(paraInativa, 'inativa');
        assertErro(deInativa, 'inativa');
    }

    @IsTest
    static void saidasNoMesmoLoteAcumulamESomaEntradaAnterior() {
        montar();
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 50);
        Movimentacao_Estoque__c s1 = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 30);
        Movimentacao_Estoque__c s2 = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 30);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ s1, s2 });
        Assert.isFalse(s1.hasErrors());
        assertErro(s2, 'Saldo insuficiente');

        Movimentacao_Estoque__c entrada = mov(MovimentacaoTipo.ENTRADA, null, p1.Id, 100);
        Movimentacao_Estoque__c saida = mov(MovimentacaoTipo.SAIDA, p1.Id, null, 120);
        MovimentacaoValidator.validar(new List<Movimentacao_Estoque__c>{ entrada, saida });
        Assert.isFalse(entrada.hasErrors());
        Assert.isFalse(saida.hasErrors(), 'a entrada anterior na mesma lista cobre a saída');
    }

    @IsTest
    static void duzentasSaidasComSaldoDeCemAceitamExatamenteCem() {
        montar();
        TestDataFactory.criarSaldo(lote.Id, p1.Id, 100);
        List<Movimentacao_Estoque__c> lista = new List<Movimentacao_Estoque__c>();
        for (Integer i = 0; i < 200; i++) {
            lista.add(mov(MovimentacaoTipo.SAIDA, p1.Id, null, 1));
        }
        Integer queriesAntes = Limits.getQueries();
        MovimentacaoValidator.validar(lista);
        Assert.isTrue(Limits.getQueries() - queriesAntes <= 3, 'no máximo 3 consultas (lotes, posições, saldos)');
        Integer aceitas = 0;
        for (Movimentacao_Estoque__c m : lista) {
            if (!m.hasErrors()) { aceitas++; }
        }
        Assert.areEqual(100, aceitas);
    }
}
