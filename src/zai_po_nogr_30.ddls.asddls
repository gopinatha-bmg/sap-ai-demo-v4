@AbapCatalog.sqlViewName: 'ZV_PO_NO_GR30'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO High Value without GR within 30 days'
@VDM.viewType: #CONSUMPTION
define view ZAI_PO_NOGR_30
  with parameters
    p_bedat_from       : bedat,
    p_bedat_to         : bedat,
    p_company_code     : bukrs,
    p_amount_threshold : netwr
  as select from ekko as po
    inner join      ekpo as poi on  poi.ebeln = po.ebeln
    left outer join lfa1 as v   on  v.lifnr   = po.lifnr
{
  key po.ebeln                                                     as PurchaseOrder,
  key poi.ebelp                                                    as POItem,
      po.bukrs                                                     as CompanyCode,
      po.bsart                                                     as POType,
      po.lifnr                                                     as Supplier,
      v.name1                                                      as SupplierName,
      po.bedat                                                     as POCreationDate,
      po.waers                                                     as Currency,
      poi.netwr                                                    as NetOrderValue,
      poi.werks                                                    as Plant,
      poi.matnr                                                    as Material,
      dats_days_between( po.bedat, $session.system_date )          as DaysSincePOCreation,
      cast( 3 as abap.int1 )                                       as RiskCriticality
}
where po.bedat   between :p_bedat_from and :p_bedat_to
  and po.bukrs   =       :p_company_code
  -- TODO: currency filter hard-coded; parameterise or apply FX conversion for multi-currency use
  and po.waers   =       'EUR'
  -- TODO: also evaluate po.loekz (header) and poi.elikz (delivery complete) per business need
  and poi.loekz  =       ''
  -- Threshold currently applied per item; TODO switch to header-total via a base CDS that
  -- aggregates sum(poi.netwr) by ebeln if the rule is header-level (>10,000 EUR per PO).
  and poi.netwr  >=      :p_amount_threshold
  -- Only consider POs that have had at least 30 days to receive goods
  and po.bedat   <=      add_days( $session.system_date, -30 )
  -- No goods receipt posted within 30 days of PO creation
  -- TODO: refine to exclude reversal / cancellation rows (e.g. bwart in 101/103/105,
  --       or net SHKZG S vs H) once movement-type policy is confirmed.
  and not exists ( select *
                     from ekbe as gr
                    where gr.ebeln = poi.ebeln
                      and gr.ebelp = poi.ebelp
                      and gr.bewtp = 'E'
                      and gr.budat between po.bedat
                                       and add_days( po.bedat, 30 ) )