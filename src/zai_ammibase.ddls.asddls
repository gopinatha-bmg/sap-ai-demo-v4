@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZV_AMMISB1'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'FI Amount Mismatch Exceptions Base'
define view ZAI_AMMIBASE
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_posting_date_from : budat,
    @EndUserText.label: 'Posting Date To'
    p_posting_date_to   : budat,
    @EndUserText.label: 'Company Code'
    p_company_code      : bukrs,
    @EndUserText.label: 'Amount Threshold'
    p_amount_threshold  : netwr_ap,
    @EndUserText.label: 'Current Fiscal Year'
    p_fiscal_year       : gjahr
  as select from bkpf as a
    inner join bseg as b
      on a.bukrs = b.bukrs
     and a.belnr = b.belnr
     and a.gjahr = b.gjahr
{
  key a.bukrs                               as CompanyCode,
  key a.belnr                               as AccountingDocument,
  key a.gjahr                               as FiscalYear,
  key b.buzei                               as AccountingDocumentItem,
      a.budat                               as PostingDate,
      a.blart                               as DocumentType,
      a.bldat                               as DocumentDate,
      a.xblnr                               as ReferenceDocumentNumber,
      b.lifnr                               as Vendor,
      b.hkont                               as GLAccount,
      b.waers                               as Currency,
      b.wrbtr                               as DocumentAmount,
      cast( a.xblnr as abap.dec( 15, 2 ) )  as ReferenceAmount,
      cast( 3 as abap.int1 )                as RiskCriticality,
      $parameters.p_amount_threshold        as AmountThreshold
}
where a.budat between $parameters.p_posting_date_from and $parameters.p_posting_date_to
  and a.bukrs = $parameters.p_company_code
  and a.gjahr = $parameters.p_fiscal_year
  and a.stblg = ''
  and b.koart = 'K'
  and b.lifnr <> ''
  and a.xblnr <> ''
;

@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZV_AMTMTCH01'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'FI Amount Mismatch Exceptions'
@VDM.viewType: #CONSUMPTION
define view ZAI_AMT_MIS1
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_posting_date_from : budat,
    @EndUserText.label: 'Posting Date To'
    p_posting_date_to   : budat,
    @EndUserText.label: 'Company Code'
    p_company_code      : bukrs,
    @EndUserText.label: 'Amount Threshold'
    p_amount_threshold  : netwr_ap,
    @EndUserText.label: 'Current Fiscal Year'
    p_fiscal_year       : gjahr
  as select from ZAI_AMMIBASE(
      p_posting_date_from: $parameters.p_posting_date_from,
      p_posting_date_to  : $parameters.p_posting_date_to,
      p_company_code     : $parameters.p_company_code,
      p_amount_threshold : $parameters.p_amount_threshold,
      p_fiscal_year      : $parameters.p_fiscal_year ) as x
{
  key x.CompanyCode,
  key x.AccountingDocument,
  key x.FiscalYear,
  key x.AccountingDocumentItem,
      x.PostingDate,
      x.DocumentType,
      x.DocumentDate,
      x.ReferenceDocumentNumber,
      x.Vendor,
      x.GLAccount,
      x.Currency,
      x.DocumentAmount,
      x.ReferenceAmount,
      x.RiskCriticality
}
where ( x.DocumentAmount <= x.ReferenceAmount - x.AmountThreshold
     or x.DocumentAmount >= x.ReferenceAmount + x.AmountThreshold )
;