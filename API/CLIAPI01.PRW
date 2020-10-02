#INCLUDE "PROTHEUS.CH"
#INCLUDE "RESTFUL.CH"
#INCLUDE "FWMVCDEF.CH"


WSRESTFUL Clientes DESCRIPTION "Serviço REST Clientes"

    WSDATA codCli as String Optional
    WSDATA codLoja as String Optional
    WSDATA page as Integer Optional
    WSDATA pageSize as Integer Optional
    WSDATA searchKey as String Optional
    WSDATA searchOrder as String Optional

    WSMETHOD GET All DESCRIPTION "Retorno do cliente" WSSYNTAX "/clientes?{page,pageSize,searchKey,searchOrder}" PATH ""
    WSMETHOD GET Unique DESCRIPTION "Retorno do cliente" WSSYNTAX "/clientes/{codCli}/loja/{codLoja}";
        PATH "/{codCli}/loja/{codLoja}"
    WSMETHOD POST  DESCRIPTION "Incluir cliente" WSSYNTAX "/clientes" PATH "/clientes"  PRODUCES APPLICATION_JSON
    WSMETHOD PUT  DESCRIPTION "alterar cliente" WSSYNTAX "/clientes" PATH "/{codCli}/loja/{codLoja}"
    WSMETHOD DELETE  DESCRIPTION "Deletar cliente" WSSYNTAX "/clientes" PATH "/{codCli}/loja/{codLoja}"

END WSRESTFUL

WSMETHOD GET All WSRECEIVE page, pageSize,searchKey, searchOrder WSSERVICE Clientes
    Local aCliente :={}
    Local cJson as String
    Local jCliente
    Local nX as Integer
    Local nNext as Integer
    Local nPage := self:page
    Local nPageSize := self:pageSize
    Local cSearchKey := self:searchKey
    Local cSearchOrder := self:searchOrder
    Local cWhere as String

    Default nPage := 1
    If nPage<0
        nPage := 1
    EndIf

    Default nPageSize := 5
    If nPageSize<0 .and. nPageSize >15
        nPageSize := 5
    EndIf

    If (cSearchOrder != "DESC" .And. cSearchOrder != "ASC")
        cSearchOrder:="ASC"
    EndIf


    ::SetContentType("aplication/json")

    If !empty(cSearchKey)
        cWhere :=" (A1_NOME like '%"+cSearchKey+"%') AND "

    Else
        cWhere := "1 = 1 AND"

    EndIf
    cOrderBy := " ORDER BY A1_COD " + cSearchOrder
    cWhere :='%'+cWhere+'%'
    cOrderBy :='%'+cOrderBy+'%'
    BeginSql Alias "TRT"
            SELECT 
                A1_CGC,
                A1_COD,
                A1_LOJA,
                A1_NOME,
                A1_TIPO,
                A1_EST,
                A1_MUN
            FROM %table:SA1% SA1
            WHERE 
            %exp:cWhere%
            SA1.%notdel%
            %exp:cOrderBy%

    EndSql

    //encontrar inicio do registro, pulando paginas se necessário
    If (!TRT->(EOF()))
        nNext := nPageSize * (nPage-1)
        If nNext >0
            TRT->(DbSkip(nNext))
        EndIf

    EndIf

    While (!TRT->(EOF()) .and. nx < nPageSize )
        nX++
        AAdd(aCliente, JsonObject():New())
        aCliente[nX]["CGC"] := TRT->A1_CGC
        aCliente[nX]["Codigo"] := TRT->A1_COD
        aCliente[nX]["Loja"] := TRT->A1_LOJA
        aCliente[nX]["Nome"] := TRT->A1_NOME
        aCliente[nX]["Nome Fantasia"] := TRT->A1_TIPO
        aCliente[nX]["Estado"] := TRT->A1_EST
        aCliente[nX]["Municipio"] := TRT->A1_MUN
        aCliente[nX]["Endereco"] := TRT->A1_MUN
        TRT->(DbSkip())
    End
    TRT->(DbCloseArea())
    jCliente := JsonObject():New()
    jCliente["CLiente"] := aCliente
    cJson := jCliente:toJson()
    ::setResponse(cJson)
Return .T.

WSMETHOD GET Unique WSSERVICE Clientes
    Local aAreaSA1 := GetArea()
    Local aCliente :={}
    Local cCodCliente as char
    Local cCodLoja as char
    Local cStatus as char
    Local cJson as String
    Local jCliente
    Local cError as String

    cCodCliente := Self:codCli
    cCodLoja := Self:codLoja
    aAreaSA1 := SA1->(GetArea())

    ::SetContentType("aplication/json")
    conout("entrou")
    DbSelectArea("SA1")
    SA1->(DbSetOrder(1))
    If SA1->(DbSeek(xFilial("SA1")+cCodCliente+cCodLoja))
        cStatus := iIf(SA1->A1_MSBLQL == "1", "Sim", "Nao")
        AAdd(aCliente, JsonObject():New())
        aCliente[1]["CGC"] := SA1->A1_CGC
        aCliente[1]["Codigo"] := SA1->A1_COD
        aCliente[1]["Loja"] := SA1->A1_LOJA
        aCliente[1]["Nome"] := SA1->A1_NOME
        aCliente[1]["Nome Fantasia"] := SA1->A1_TIPO
        aCliente[1]["Estado"] := SA1->A1_EST
        aCliente[1]["Municipio"] := SA1->A1_MUN
        aCliente[1]["Endereco"] := SA1->A1_END
        jCliente := JsonObject():New()
        jCliente["CLiente"] := aCliente
        cJson := jCliente:toJson()
        ::setResponse(cJson)
    Else
        cError := encodeUTF8("Não enconrtado..")
        setRestFault(1,cError, .T., 404 )
    EndIf
Return .T.

WSMETHOD POST WSSERVICE clientes
    Local jCliente
    Local cError as char
    Local cJson as String
    Local cAlias := Alias()
    Local lOk :=.F.

    Self:SetContentType("aplication/json")
    jCliente := JsonObject():New()
    cError := jCliente:fromJson(::getContent())

    If Empty(cError)
        DbSelectArea("SA1")
        SA1-> (DbSetOrder(1))
        If !SA1->(DbSeek(xFilial("SA1")+jCliente["CODCLIENTE"]+jCliente["CODLOJA"]))
            oModel := FwLoadModel("MATA030")
            oModel:setOperation(3)
            oModel:Activate()
            oSA1Mod := oModel:getModel("MATA030_SA1")
            oSA1Mod:setValue("A1_COD", jCliente["CODCLIENTE"])
            oSA1Mod:setValue("A1_LOJA", jCliente["CODLOJA"])
            oSA1Mod:setValue("A1_NOME", jCliente["NOME"])
            oSA1Mod:setValue("A1_NREDUZ", jCliente["NOMEFANTASIA"])
            oSA1Mod:setValue("A1_TIPO",jCliente["TIPO"])
            oSA1Mod:setValue("A1_EST", jCliente["ESTADO"])
            oSA1Mod:setValue("A1_MUN", jCliente["MUNICIPIO"])
            oSA1Mod:setValue("A1_END", jCliente["ENDERECO"])
            If oModel:VldData()
                lOk := oModel:CommitData()
                cJson := '{"CODCLIENTE:"' + SA1->A1_COD +'}'
                ::setResponse(cJson)
            Else
                cError := oModel:GetErrorMessage()[MODEL_MSGERR_MESSAGE]
                setRestFault(2, cError, .T., 422)
            EndIf
            
            If !Empty(cError)
                DbSelectArea(cAlias)
            EndIf
            oModel:Deactivate()
            oModel:Destroy()
            oModel := nil
        Else
            cError :=encodeUTF8("Cliente j cadastrado ")
            setRestFault(3,cError +SA1->A1_COD, .T., 400)
        EndIf
    EndIf

Return lOk

WSMETHOD PUT PATHPARAM codCli, codLoja  WSSERVICE clientes
    Local jCliente
    Local cError as String
    Local cJson as String
    Local cAlias := Alias()
    Local lOk as logical
    Local cCodCliente := self:codCli
    Local cCodLoja := self:codLoja

    ::SetContentType("aplication/json")
    jCliente := JsonObject():New()
    cError := jCliente:fromJson(::getContent())

    If Empty(cError)
        DbSelectArea("SA1")
        SA1-> (DbSetOrder(1))
        If SA1->(DbSeek(xFilial("SA1")+cCodCliente+cCodLoja))
            oModel := FwLoadModel("MATA030")
            oModel:setOperation(4)
            oModel:Activate()
            oSA1Mod := oModel:getModel("MATA030_SA1")
            oSA1Mod:setValue("A1_NOME", jCliente["NOME"])
            oSA1Mod:setValue("A1_NREDUZ", jCliente["NOMEFANTASIA"])
            oSA1Mod:setValue("A1_TIPO",jCliente["TIPO"])
            oSA1Mod:setValue("A1_EST", jCliente["ESTADO"])
            oSA1Mod:setValue("A1_MUN", jCliente["MUNICIPIO"])
            oSA1Mod:setValue("A1_END", jCliente["ENDERECO"])
            If oModel:VldData()
                lOk := oModel:CommitData()
                cJson := '{"CODCLIENTE:"' + SA1->A1_COD +' foi deletado!}'
                ::setResponse(cJson)
            Else
                cError:= oModel:GetErrorMessage()[MODEL_MSGRR_MESSAGE]
                setRestFault(4, cError, .T., 400)
            EndIf

            If !Empty(cError)
                DbSelectArea(cAlias)
            EndIf
            oModel:Deactivate()
            oModel:Destroy()
            oModel := nil
        Else
            cError := encodeUTF8("parâmetros inválido")
            setRestFault(5, cError, .T., 400)
        EndIf
    EndIf

Return lOk

WSMETHOD DELETE PATHPARAM codCli, codLoja WSSERVICE clientes
    Local jCliente
    Local cCodCli := self:codCli
    Local cCodLoja := self:codLoja
    Local cError as String
    Local lOk as logical
    Local cjson as String
    Local cAlias := Alias()
    ::SetContentType("aplication/json")

    jCliente := JsonObject():New()
    cError := jCliente:fromJson(::getContent())

    If Empty(cError)
        DbSelectArea("SA1")
        SA1->(DbSetOrder(1))

        If SA1->(DbSeek(xFilial("SA1")+cCodCli+cCodLoja))

            oModel := FwLoadModel("MATA030")
            oModel:setOperation(5)
            oModel:Activate()

            If oModel:VldData()
                lOk:= oModel:CommitData()
                cJson := '{"CODCLIENTE:"' + SA1->A1_COD +'}'
                ::setResponse(cJson)
            Else
                cError := oModel:GetErrorMessage()[MODEL_MSGERR_MESSAGE]
                setRestFalt(6, cError, .T., 400)
            EndIf
            oModel:Deactivate()
            oModel:Destroy()
            oModel := nil

        Else
            cError :=encodeUTF8("Não foi encontrado com os parametrôs mencionados.")
            setRestFault(7,cError, .T., 400)
        EndIf
        If !Empty(cError)
            DbSelectArea(cAlias)
        EndIf
    Else

        setRestFault(8,cError, .T., 400)

    EndIf

Return lOK
