#INCLUDE "PROTHEUS.CH"
#INCLUDE "RESTFUL.CH"
#INCLUDE "FWMVCDEF.CH"


WSRESTFUL Pedidos DESCRIPTION "Pedido de vendas"
    WSDATA idPedido as Char Optional

    WSMETHOD GET Unique DESCRIPTION "Listar pedido de venda" WSSYNTAX "/{idPedido}" PATH "/{idPedido}"
    WSMETHOD POST  DESCRIPTION "Listar pedido de venda" WSSYNTAX "/Pedidos" PRODUCES APPLICATION_JSON
    WSMETHOD PUT  DESCRIPTION "Listar pedido de venda" WSSYNTAX  "/{idPedido}" PATH "/{idPedido}"
    WSMETHOD DELETE  DESCRIPTION "Listar pedido de venda" WSSYNTAX  "/{idPedido}" PATH "/{idPedido}"

END WSRESTFUL

WSMETHOD GET Unique WSSERVICE Pedidos
    Local cIdPedido :=Space(6)
    Local aSC5 :={}
    Local aSC6 :={}
    Local jSC5
    Local cJson as String
    Local cStatus as char
    Local aPedidos := {}
    Local cError as String
    Local lRet := .T.

    cIdPedido := Self:idPedido
    If empty(cIdPedido) .or. len(cIdPedido)<6
        lRet := .F.
        cError := encodeUTF8("parâmetros em branco ou invalido")
        setRestFault(1, cError, .T., 400)
    EndIf
    //define o tipo de retorno
    ::SetContentType("aplication/json")
    DbselectArea("SC5")
    SC5->(DbSetOrder(1))

    If SC5->(DbSeek(xFilial("SC5")+cIdPedido))
        cStatus := iIf(SA1->A1_MSBLQL == "1", "Sim", "Nao")
        AAdd(aSC5, JsonObject():New())
        aSC5[1]["FILIAL"]:=SC5->C5_FILIAL
        aSC5[1]["PEDIDO"]:=SC5->C5_NUM
        aSC5[1]["CLIENTE"]:=SC5->C5_CLIENTE
        aSC5[1]["NOMECLI"]:=alltrim(posicione("SA1",1,xFilial("SA1")+SC5->C5_CLIENTE+SC5->C5_LOJACLI,"A1_NOME"))
        aSC5[1]["LOJACLI"]:=SC5->C5_LOJACLI
        aSC5[1]["VENDEDOR"]:=alltrim((SC5->C5_VEND1))
        aSC5[1]["PAGAMENTO"]:=SC5->C5_CONDPAG
        aPedidos := ItemPed(cIdPedido)
        for nX := 1 to len(aPedidos)
            AAdd(aSC6, JsonObject():New())
            aSC6[nX]["ITEM"] :=aPedidos[nX][2]
            aSC6[nX]["PRODUTO"] :=alltrim(aPedidos[nX][3])
            aSC6[nX]["UM"] :=aPedidos[nX][4]
            aSC6[nX]["QTDVEN"] :=aPedidos[nX][5]
            aSC6[nX]["PRCVEN"] :=aPedidos[nX][6]
            aSC6[nX]["VALOR"] :=aPedidos[nX][7]
        next nX

        aSC5[1]["ITENS"]:=aSC6
        //intancia json
        jSC5 := JsonObject():New()
        //atribuo o array para json
        jSC5["CabecPedido"]:=aSC5
        //json para string
        cJson := jSC5:toJson()
        //retorno
        self:setResponse(cJson)
        SC5->(DbCloseArea())
    Else
        lRet:= .F.
        cError := encodeUTF8("Não enconrtado..")
        setRestFault(2, cError, .T. , 400)
    EndIf

Return lRet

WSMETHOD POST WSSERVICE Pedidos
    Local jPedido
    Local cError as char
    Local cJson as String
    Local lRet := .T.
    Local aCabec := {}
    Local aItens :={}
    Private lMsErroAuto := .F.
    //definir tipo
    Self:SetContentType("aplication/json")
    //instancia de json
    jPedido := JsonObject():New()
    cError := jPedido:fromJson(Self:getContent())

    If Empty(cError)
        aadd(aCabec, {"C5_FILIAL",jPedido["CabecPedido"][1]["FILIAL"],      Nil})
        aadd(aCabec, {"C5_TIPO",    "N",       Nil})
        aadd(aCabec, {"C5_CLIENTE", jPedido["CabecPedido"][1]["CLIENTE"], Nil})
        aadd(aCabec, {"C5_LOJACLI", jPedido["CabecPedido"][1]["LOJACLI"],   Nil})
        aadd(aCabec, {"C5_LOJAENT", jPedido["CabecPedido"][1]["LOJACLI"],   Nil})
        aadd(aCabec, {"C5_CONDPAG",jPedido["CabecPedido"][1]["PAGAMENTO"], Nil})

        For nX := 1 to len(jPedido["CabecPedido"][1]["ITENS"])
            AAdd(aItens,{{"C6_PRODUTO",jPedido["CabecPedido"][1]["ITENS"][nX]["PRODUTO"], Nil},;
                {"C6_ITEM", StrZero(nX,2), Nil},;
                {"C6_QTDVEN",jPedido["CabecPedido"][1]["ITENS"][nX]["QTDVEN"], Nil},;
                {"C6_PRCVEN",jPedido["CabecPedido"][1]["ITENS"][nX]["PRCVEN"], Nil},;
                {"C6_PRUNIT",jPedido["CabecPedido"][1]["ITENS"][nX]["PRUNIT"], Nil},;
                {"C6_TES","501", Nil}})
        next nX
        MSExecAuto({|a, b, c, d| MATA410(a, b, c, d)}, aCabec, aItens, 3)
        If !lMsErroAuto

            cJson := '{"PEDIDO:"' +SC5->C5_NUM + '}'
            ::setResponse(cJson)
        Else
            setResponse(5,encodeUTF8("Não foi inseriro o pedido.."),.T., 400)
        EndIf

    Else
        lRet := .F.
        setRestFault(3,"erro.....")
    EndIf

Return lRet
WSMETHOD PUT WSSERVICE Pedidos
    conout("em desenvolvimento")
Return .F.

WSMETHOD DELETE WSSERVICE Pedidos
    conout("em desenvolvimento")
Return .F.


static Function ItemPed(cPedido)
    Local aSC6 := {}
    Local TRT01 := GetNextAlias()

    BeginSql alias TRT01
    SELECT  C6_FILIAL,
            C6_ITEM,
            C6_PRODUTO,
            C6_UM,
            C6_QTDVEN,
            C6_PRCVEN,
            C6_VALOR
    FROM %table:SC6% SC6
    WHERE C6_NUM = %exp:cPedido%  
    AND      SC6.%notdel%


    EndSql

    while !(TRT01)->(EOF())

        AAdd(aSC6,{(TRT01)->C6_FILIAL;
            ,(TRT01)->C6_ITEM;
            ,(TRT01)->C6_PRODUTO;
            ,(TRT01)->C6_UM;
            ,(TRT01)->C6_QTDVEN;
            ,(TRT01)->C6_PRCVEN;
            ,(TRT01)->C6_VALOR})
        (TRT01)->(DbSkip())
    endDo

    (TRT01)->(DbCloseArea())

Return aSC6
