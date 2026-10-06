public with sharing class WmsController {
    public class OpcaoDeposito {
        @AuraEnabled public Id id;
        @AuraEnabled public String nome;
    }
    public class PosicaoVisao {
        @AuraEnabled public Id id;
        @AuraEnabled public String codigo;
        @AuraEnabled public Decimal capacidade;
        @AuraEnabled public Decimal ocupado;
        @AuraEnabled public Decimal percentual;
        @AuraEnabled public Boolean ativa;
    }
    public class CorredorVisao {
        @AuraEnabled public Id id;
        @AuraEnabled public String nome;
        @AuraEnabled public List<PosicaoVisao> posicoes = new List<PosicaoVisao>();
    }
    public class ZonaVisao {
        @AuraEnabled public Id id;
        @AuraEnabled public String nome;
        @AuraEnabled public String tipo;
        @AuraEnabled public List<CorredorVisao> corredores = new List<CorredorVisao>();
    }
    public class DepositoVisao {
        @AuraEnabled public List<ZonaVisao> zonas = new List<ZonaVisao>();
    }
    public class LoteAlerta {
        @AuraEnabled public Id loteId;
        @AuraEnabled public String numeroLote;
        @AuraEnabled public String produto;
        @AuraEnabled public Date validade;
        @AuraEnabled public Integer diasRestantes;
        @AuraEnabled public Decimal saldoTotal;
    }
    public class LoteOpcao {
        @AuraEnabled public Id loteId;
        @AuraEnabled public String rotulo;
        @AuraEnabled public Decimal saldo;
    }

    @AuraEnabled
    public static List<OpcaoDeposito> listarDepositos() {
        List<OpcaoDeposito> opcoes = new List<OpcaoDeposito>();
        for (Deposito__c d : [SELECT Id, Name FROM Deposito__c ORDER BY Name]) {
            OpcaoDeposito o = new OpcaoDeposito();
            o.id = d.Id;
            o.nome = d.Name;
            opcoes.add(o);
        }
        return opcoes;
    }

    @AuraEnabled
    public static DepositoVisao buscarHierarquia(Id depositoId) {
        DepositoVisao visao = new DepositoVisao();
        Map<Id, ZonaVisao> zonas = new Map<Id, ZonaVisao>();
        for (Zona__c z : [SELECT Id, Name, Tipo__c FROM Zona__c WHERE Deposito__c = :depositoId ORDER BY Name]) {
            ZonaVisao zv = new ZonaVisao();
            zv.id = z.Id;
            zv.nome = z.Name;
            zv.tipo = z.Tipo__c;
            zonas.put(z.Id, zv);
            visao.zonas.add(zv);
        }

        Map<Id, CorredorVisao> corredores = new Map<Id, CorredorVisao>();
        for (Corredor__c c : [
            SELECT Id, Name, Zona__c FROM Corredor__c WHERE Zona__r.Deposito__c = :depositoId ORDER BY Name
        ]) {
            CorredorVisao cv = new CorredorVisao();
            cv.id = c.Id;
            cv.nome = c.Name;
            corredores.put(c.Id, cv);
            zonas.get(c.Zona__c).corredores.add(cv);
        }

        Map<Id, Decimal> ocupacao = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Posicao__c posicao, SUM(Quantidade_Atual__c) total
            FROM Saldo_Estoque__c
            WHERE Posicao__r.Corredor__r.Zona__r.Deposito__c = :depositoId
            GROUP BY Posicao__c
        ]) {
            ocupacao.put((Id) ar.get('posicao'), (Decimal) ar.get('total'));
        }

        for (Posicao__c p : [
            SELECT Id, Name, Capacidade_Maxima__c, Ativa__c, Corredor__c
            FROM Posicao__c
            WHERE Corredor__r.Zona__r.Deposito__c = :depositoId
            ORDER BY Name
        ]) {
            PosicaoVisao pv = new PosicaoVisao();
            pv.id = p.Id;
            pv.codigo = p.Name;
            pv.capacidade = p.Capacidade_Maxima__c;
            pv.ocupado = ocupacao.containsKey(p.Id) ? ocupacao.get(p.Id) : 0;
            pv.ativa = p.Ativa__c;
            pv.percentual = calcularPercentual(pv.ocupado, p.Capacidade_Maxima__c);
            corredores.get(p.Corredor__c).posicoes.add(pv);
        }
        return visao;
    }

    @AuraEnabled
    public static List<LoteAlerta> lotesAVencer(Integer dias) {
        Integer janela = (dias == null || dias < 0) ? 30 : dias;
        Date hoje = Date.today();
        Date limite = hoje.addDays(janela);
        List<Lote__c> lotes = [
            SELECT Id, Name, Produto__r.Name, Data_Validade__c
            FROM Lote__c
            WHERE Data_Validade__c != NULL
              AND Data_Validade__c <= :limite
              AND Id IN (SELECT Lote__c FROM Saldo_Estoque__c WHERE Quantidade_Atual__c > 0)
            ORDER BY Data_Validade__c ASC
            LIMIT 200
        ];
        Map<Id, Decimal> totais = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Lote__c lote, SUM(Quantidade_Atual__c) total
            FROM Saldo_Estoque__c WHERE Lote__c IN :lotes GROUP BY Lote__c
        ]) {
            totais.put((Id) ar.get('lote'), (Decimal) ar.get('total'));
        }

        List<LoteAlerta> alertas = new List<LoteAlerta>();
        for (Lote__c l : lotes) {
            LoteAlerta a = new LoteAlerta();
            a.loteId = l.Id;
            a.numeroLote = l.Name;
            a.produto = l.Produto__r.Name;
            a.validade = l.Data_Validade__c;
            a.diasRestantes = hoje.daysBetween(l.Data_Validade__c);
            a.saldoTotal = totais.containsKey(l.Id) ? totais.get(l.Id) : 0;
            alertas.add(a);
        }
        return alertas;
    }

    @AuraEnabled
    public static List<LoteOpcao> lotesDisponiveis(Id produtoId, Id posicaoId) {
        Date hoje = Date.today();
        List<LoteOpcao> opcoes = new List<LoteOpcao>();
        for (Saldo_Estoque__c s : [
            SELECT Lote__c, Lote__r.Name, Lote__r.Data_Validade__c, Quantidade_Atual__c
            FROM Saldo_Estoque__c
            WHERE Posicao__c = :posicaoId
              AND Lote__r.Produto__c = :produtoId
              AND Quantidade_Atual__c > 0
              AND (Lote__r.Data_Validade__c = NULL OR Lote__r.Data_Validade__c >= :hoje)
            ORDER BY Lote__r.Data_Validade__c ASC NULLS LAST, Lote__r.CreatedDate ASC
            LIMIT 50
        ]) {
            LoteOpcao o = new LoteOpcao();
            o.loteId = s.Lote__c;
            Date validade = s.Lote__r.Data_Validade__c;
            o.rotulo = s.Lote__r.Name
                + (validade == null ? ' (sem validade)' : ' (val. ' + String.valueOf(validade) + ')')
                + ' — saldo ' + s.Quantidade_Atual__c;
            o.saldo = s.Quantidade_Atual__c;
            opcoes.add(o);
        }
        return opcoes;
    }

    @AuraEnabled
    public static Id registrarMovimentacao(
        String tipo, Id loteId, Id origemId, Id destinoId, Decimal quantidade
    ) {
        Movimentacao_Estoque__c m = new Movimentacao_Estoque__c(
            Tipo__c = tipo,
            Lote__c = loteId,
            Posicao_Origem__c = origemId,
            Posicao_Destino__c = destinoId,
            Quantidade__c = quantidade
        );
        try {
            insert m;
            return m.Id;
        } catch (DmlException e) {
            if (e.getDmlType(0) == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
                throw erroAura(e.getDmlMessage(0));
            }
            ErrorLogger.log(e, 'WmsController.registrarMovimentacao');
            throw erroAura('Erro inesperado ao registrar a movimentação. Consulte os Logs de Erro.');
        } catch (Exception e) {
            ErrorLogger.log(e, 'WmsController.registrarMovimentacao');
            throw erroAura('Erro inesperado ao registrar a movimentação. Consulte os Logs de Erro.');
        }
    }

    private static Decimal calcularPercentual(Decimal ocupado, Decimal capacidade) {
        if (capacidade == null || capacidade <= 0) { return 0; }
        Decimal bruto = (ocupado * 100 / capacidade).setScale(0, RoundingMode.HALF_UP);
        return Math.min(100, bruto);
    }

    private static AuraHandledException erroAura(String mensagem) {
        AuraHandledException e = new AuraHandledException(mensagem);
        e.setMessage(mensagem);
        return e;
    }
}
