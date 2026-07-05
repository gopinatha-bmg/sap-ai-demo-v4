@AbapCatalog.sqlViewName: 'ZV_JE_ANOM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Anomalies'
@VDM.viewType: #CONSUMPTION

define view ZAI_JE_ANOM
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_budat_from       : budat,
    @EndUserText.label: 'Posting Date To'
    p_budat_to         : budat,
    @EndUserText.label: 'Header Amount Threshold (Doc Currency)'
    p_hdr_threshold    : abap.dec(15,2)
  as select from bkpf as h
    inner join   bseg as i on  i.bukrs = h.bukrs
                           AND i.belnr = h.belnr
                           AND i.gjahr = h.gjahr
    left outer join lfa1 as v on v.lifnr = i.lifnr
{
  key h.bukrs                          as CompanyCode,
  key h.belnr                          as AccountingDocument,
  key h.gjahr                          as FiscalYear,
  key i.buzei                          as LineItem,
      h.blart                          as DocumentType,
      h.bldat                          as DocumentDate,
      h.budat                          as PostingDate,
      h.monat                          as FiscalPeriod,
      h.cpudt                          as EntryDate,
      h.usnam                          as EnteredBy,
      h.xblnr                          as ExternalReference,

      @Semantics.currencyCode: true
      h.waers                          as DocumentCurrency,

      h.bstat                          as DocumentStatus,
      h.stblg                          as ReverseDocument,
      i.koart                          as AccountType,
      i.shkzg                          as DebitCreditIndicator,

      @Semantics.amount.currencyCode: 'DocumentCurrency'
      i.wrbtr                          as AmountInDocCurrency,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      i.dmbtr                          as AmountInLocalCurrency,

      // Local currency for dmbtr (BSEG.dmbtr is in company code currency)
      // TODO: replace constant with join to T001-waers if strict typing required
      cast( '' as waers preserving type )  as CompanyCodeCurrency,

      i.hkont                          as GLAccount,
      i.lifnr                          as Vendor,
      v.name1                          as VendorName,

      // Header-level total in document currency (signed via SHKZG)
      // Anomaly A: document is unbalanced if sum(signed wrbtr) <> 0
      ( select sum( case when b2.shkzg = 'H'
                         then b2.wrbtr * -1
                         else b2.wrbtr
                    end )
          from bseg as b2
         where b2.bukrs = h.bukrs
           and b2.belnr = h.belnr
           and b2.gjahr = h.gjahr )    as HeaderBalanceDocCurr,

      // Header gross total (absolute debits) for threshold evaluation
      ( select sum( b3.wrbtr )
          from bseg as b3
         where b3.bukrs = h.bukrs
           and b3.belnr = h.belnr
           and b3.gjahr = h.gjahr
           and b3.shkzg = 'S' )        as HeaderDebitTotalDocCurr,

      // Anomaly flags (evaluated per line, but derived at header level)
      case when ( select sum( case when b2.shkzg = 'H'
                                   then b2.wrbtr * -1
                                   else b2.wrbtr
                              end )
                    from bseg as b2
                   where b2.bukrs = h.bukrs
                     and b2.belnr = h.belnr
                     and b2.gjahr = h.gjahr ) <> 0
           then 'X' else '' end        as IsUnbalanced,

      case when ( select sum( b3.wrbtr )
                    from bseg as b3
                   where b3.bukrs = h.bukrs
                     and b3.belnr = h.belnr
                     and b3.gjahr = h.gjahr
                     and b3.shkzg = 'S' ) > :p_hdr_threshold
           then 'X' else '' end        as ExceedsThreshold,

      // TODO: Closed-period check requires T001B (posting period control) and
      //       T001-periv/MONAT resolution. Recommended pattern: build a
      //       separate CDS ZAI_OPEN_PERIOD exposing (BUKRS, GJAHR, MONAT,
      //       is_open) and left-join here, flagging is_open = ''.
      //       Left as placeholder to avoid embedding client-specific config.
      cast( '' as abap.char(1) )       as IsClosedPeriod,

      // Criticality set as constant; UI / consumption layer can override
      cast( 3 as abap.int1 )           as RiskCriticality
}
where h.budat between :p_budat_from and :p_budat_to
  AND h.bstat <> 'S'                    // exclude reversed / statistical docs per brief
  AND h.bukrs <> '9999'                 // exclude test company code
  AND i.dmbtr >= 100                    // exclude immaterial line items (< 100 local ccy)
  // TODO: scope to EUR documents or add currency conversion if the 100000
  //       header threshold must be strictly EUR-denominated. Currently the
  //       threshold parameter is evaluated in document currency.