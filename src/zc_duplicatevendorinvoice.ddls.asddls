@OData.publish: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZC_DUPVINV'
@AbapCatalog.compiler.compareFilter: true
@EndUserText.label: 'Duplicate Vendor Invoice Exceptions'

// Scope: FI vendor invoice line items (BSEG, KOART = 'K') that share
//   (BUKRS, LIFNR, XBLNR, WAERS, signed WRBTR) with at least one OTHER
//   document in the same posting window.
// NOTE: key_tables listed RBKP/RSEG. MM logistics invoices are not covered
//   here; add a sibling view over RBKP/RSEG if MM-side duplicates are needed.
// TODO: confirm whether match should be on absolute amount or signed amount;
//   current logic matches on (shkzg, wrbtr) so invoice vs. credit memo do
//   not collide.

define view entity ZC_DuplicateVendorInvoice
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_posting_date_from : abap.dats,
    @EndUserText.label: 'Posting Date To'
    p_posting_date_to   : abap.dats,
    @EndUserText.label: 'Fiscal Year'
    p_fiscal_year       : gjahr,
    @EndUserText.label: 'Amount Threshold (example only)'
    p_amount_threshold  : abap.dec( 15, 2 )

  as select from bkpf as h
    inner join bseg as i
      on  i.bukrs = h.bukrs
      and i.belnr = h.belnr
      and i.gjahr = h.gjahr

{
  key h.bukrs                          as CompanyCode,
  key h.belnr                          as AccountingDocumentNo,
  key h.gjahr                          as FiscalYear,
  key i.buzei                          as LineItem,
      h.blart                          as DocumentType,
      h.bldat                          as DocumentDate,
      h.budat                          as PostingDate,
      h.xblnr                          as Reference,
      h.stblg                          as ReversalDocumentNo,
      h.stgrd                          as ReversalReasonCode,
      i.koart                          as AccountType,
      i.lifnr                          as VendorAccount,
      i.shkzg                          as DebitCreditIndicator,
      i.wrbtr                          as AmountInDocCurrency,
      h.waers                          as DocumentCurrency,
      i.dmbtr                          as AmountInLocalCurrency,
      h.hwaer                          as LocalCurrency,
      i.sgtxt                          as ItemText
}
where  h.budat   between :p_posting_date_from and :p_posting_date_to
  and  h.gjahr   =  :p_fiscal_year
  and  h.bukrs  <> '9999'                  // exclude test company code
  and  h.stblg   = ''                      // not reversed
  and  i.koart   = 'K'                     // vendor lines only
  and  i.lifnr  <> ''
  and  i.xblnr  <> ''                      // matching key must be populated
  and  abs( i.wrbtr ) >= :p_amount_threshold
  and  exists ( select  from bkpf as h2
                  inner join bseg as i2
                    on  i2.bukrs = h2.bukrs
                    and i2.belnr = h2.belnr
                    and i2.gjahr = h2.gjahr
                where  h2.bukrs   =  h.bukrs
                  and  h2.waers   =  h.waers
                  and  h2.xblnr   =  h.xblnr
                  and  h2.stblg   =  ''
                  and  h2.bukrs  <> '9999'
                  and  h2.budat   between :p_posting_date_from and :p_posting_date_to
                  and  i2.koart   =  'K'
                  and  i2.lifnr   =  i.lifnr
                  and  i2.shkzg   =  i.shkzg
                  and  i2.wrbtr   =  i.wrbtr
                  and  ( h2.belnr <> h.belnr or h2.gjahr <> h.gjahr ) )