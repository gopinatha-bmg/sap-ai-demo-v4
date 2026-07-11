@AbapCatalog.sqlViewName: 'ZV_DBDOCAMT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Duplicate Business Document by Company and Year'
@VDM.viewType: #CONSUMPTION
define view ZAI_DUP_BDOC
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_posting_date_from : budat,
    @EndUserText.label: 'Posting Date To'
    p_posting_date_to   : budat,
    @EndUserText.label: 'Company Code'
    p_company_code      : bukrs,
    @EndUserText.label: 'Fiscal Year'
    p_fiscal_year       : gjahr,
    @EndUserText.label: 'Amount Threshold'
    // TODO: replace with FI-appropriate amount data element in your system if needed
    p_amount_threshold  : wrbtr
  as select from bkpf as a
    inner join (
      select from bseg
      {
        bseg.bukrs as bukrs,
        bseg.belnr as belnr,
        bseg.gjahr as gjahr,
        sum( bseg.wrbtr ) as DocAmount
      }
      group by
        bseg.bukrs,
        bseg.belnr,
        bseg.gjahr
    ) as bi
      on  a.bukrs = bi.bukrs
      and a.belnr = bi.belnr
      and a.gjahr = bi.gjahr
{
  key a.bukrs                    as CompanyCode,
  key a.gjahr                    as FiscalYear,
  key a.xblnr                    as BusinessDocumentNumber,
      count( distinct a.belnr )  as DuplicateCount,
      min( a.budat )             as FirstPostingDate,
      max( a.budat )             as LastPostingDate,
      sum( bi.DocAmount )        as TotalAmount,
      cast( 3 as abap.int1 )     as RiskCriticality
}
where a.budat between :p_posting_date_from and :p_posting_date_to
  and a.bukrs = :p_company_code
  and a.gjahr = :p_fiscal_year
  and a.stblg = ''
  and a.xblnr <> ''
  // TODO: if your process requires strict exclusion of reversal postings themselves,
  // add release-approved reversal indicators beyond STBLG, based on client design.
group by
  a.bukrs,
  a.gjahr,
  a.xblnr
having count( distinct a.belnr ) > 1
   and sum( bi.DocAmount ) >= :p_amount_threshold