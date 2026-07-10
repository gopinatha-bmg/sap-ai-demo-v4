@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZV_FIEXC001'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'FI Vendor Posting Exceptions'
@VDM.viewType: #CONSUMPTION
define view ZAI_FI_EXC1
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
    p_amount_threshold  : wrbtr
  as select from bkpf as a
    inner join bseg as b
      on  a.bukrs = b.bukrs
      and a.belnr = b.belnr
      and a.gjahr = b.gjahr
{
  key a.bukrs                as CompanyCode,
  key a.belnr                as AccountingDocument,
  key a.gjahr                as FiscalYear,
  key b.buzei                as AccountingDocumentItem,
      a.budat                as PostingDate,
      a.bldat                as DocumentDate,
      a.blart                as DocumentType,
      a.xblnr                as ReferenceDocument,
      b.lifnr                as Vendor,
      b.wrbtr                as AmountInDocumentCurrency,
      b.waers                as DocumentCurrency,
      b.shkzg                as DebitCreditCode,
      cast( 3 as abap.int1 ) as RiskCriticality,
      case
        when a.xblnr = '' then cast( 'MISSING_REFERENCE' as abap.char(20) )
        when b.lifnr = '' then cast( 'MISSING_VENDOR' as abap.char(20) )
      end                    as ExceptionReason
}
where a.budat between :p_posting_date_from and :p_posting_date_to
  and a.bukrs = :p_company_code
  and a.gjahr = :p_fiscal_year
  and a.stblg = ''
  and b.koart = 'K'
  and b.wrbtr >= :p_amount_threshold
  and (
       a.xblnr = ''
       or b.lifnr = ''
      )