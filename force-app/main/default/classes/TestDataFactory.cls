@IsTest
public class TestDataFactory {
    public static Deposito__c criarDeposito(String nome) {
        Deposito__c d = new Deposito__c(Name = nome, Ativo__c = true);
        insert d;
        return d;
    }

    public static Zona__c criarZona(Id depositoId, String nome) {
        Zona__c z = new Zona__c(Name = nome, Deposito__c = depositoId, Tipo__c = 'Armazenagem');
        insert z;
        return z;
    }

    public static Corredor__c criarCorredor(Id zonaId, String nome) {
        Corredor__c c = new Corredor__c(Name = nome, Zona__c = zonaId);
        insert c;
        return c;
    }

    public static Posicao__c criarPosicao(Id corredorId, String codigo, Decimal capacidade) {
        Posicao__c p = new Posicao__c(
            Name = codigo, Corredor__c = corredorId, Capacidade_Maxima__c = capacidade, Ativa__c = true
        );
        insert p;
        return p;
    }

    public static Posicao__c criarPosicaoCompleta(String codigo) {
        Deposito__c d = criarDeposito('Depósito ' + codigo);
        Zona__c z = criarZona(d.Id, 'Zona ' + codigo);
        Corredor__c c = criarCorredor(z.Id, 'Corredor ' + codigo);
        return criarPosicao(c.Id, codigo, 1000);
    }

    public static Produto__c criarProduto(String sku) {
        Produto__c p = new Produto__c(
            Name = 'Produto ' + sku, SKU__c = sku, Unidade_Medida__c = 'UN', Estoque_Minimo__c = 10
        );
        insert p;
        return p;
    }

    public static Lote__c criarLote(Id produtoId, String numero, Date validade) {
        Lote__c l = new Lote__c(
            Name = numero,
            Produto__c = produtoId,
            Data_Fabricacao__c = Date.today().addDays(-30),
            Data_Validade__c = validade,
            Quantidade_Recebida__c = 1000
        );
        insert l;
        return l;
    }

    public static Movimentacao_Estoque__c novaMovimentacao(
        String tipo, Id loteId, Id origemId, Id destinoId, Decimal quantidade
    ) {
        return new Movimentacao_Estoque__c(
            Tipo__c = tipo,
            Lote__c = loteId,
            Posicao_Origem__c = origemId,
            Posicao_Destino__c = destinoId,
            Quantidade__c = quantidade
        );
    }

    public static Movimentacao_Estoque__c registrar(
        String tipo, Id loteId, Id origemId, Id destinoId, Decimal quantidade
    ) {
        Movimentacao_Estoque__c m = novaMovimentacao(tipo, loteId, origemId, destinoId, quantidade);
        insert m;
        return m;
    }

    public static Saldo_Estoque__c criarSaldo(Id loteId, Id posicaoId, Decimal quantidade) {
        Saldo_Estoque__c s = new Saldo_Estoque__c(
            Chave__c = SaldoEstoqueService.chave(loteId, posicaoId),
            Lote__c = loteId,
            Posicao__c = posicaoId,
            Quantidade_Atual__c = quantidade
        );
        TriggerHandler.bypass('SaldoEstoqueTriggerHandler');
        insert s;
        TriggerHandler.clearBypass('SaldoEstoqueTriggerHandler');
        return s;
    }

    public static Decimal saldo(Id loteId, Id posicaoId) {
        List<Saldo_Estoque__c> linhas = [
            SELECT Quantidade_Atual__c FROM Saldo_Estoque__c
            WHERE Lote__c = :loteId AND Posicao__c = :posicaoId
        ];
        return linhas.isEmpty() ? 0 : linhas[0].Quantidade_Atual__c;
    }
}
