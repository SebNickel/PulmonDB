#' Annotation from PulmonDB
#'
#' This gives you manually curated annotation for all GSEs available
#' in PulmonDB.
#'
#' Details.
#' PulmonDB has contrast values (test_condition vs reference), which
#' curated annotation can be returned using annotationPulmonDB(),
#' default option is annotation by "contrast" and it will give you
#' a string with the test and the reference annotation separated by
#' "_vs_" (EMPHYSEMA_vs_HEALTHY/CONTROL).
#'
#' It also has the opption to retrieve annotation per sample using
#' the condition output = "sample".
#'
#' Sometimes the feature annotated can be empty when two o more
#' GSEs are downloaded. Each GSE has different
#' annotation and not allways all annotation features are available.
#'
#'
#' @param output "contrast" or "sample". Default is "contrast" but it also can
#' be changed to return annotation per "sample"
#' @inheritParams genesPulmonDB
#' @source \url{http://pulmondb.liigh.unam.mx/}
#'
#' @export
#' @import RMySQL
#' @import dplyr
#' @import SummarizedExperiment
#' @importFrom ontologyIndex ontology_index
#' @importFrom magrittr "%>%"
#' @importFrom plyr revalue
#' @return This is the result.
#' @examples
#' ## Annotation per contrast
#' annotationPulmonDB("GSE27536")
#' annotationPulmonDB("GSE27536","contrast")
#' ## Annotation per sample
#' annotationPulmonDB(c("GSE101286","GSE1122"),"sample")
#'
#'
#' @seealso [genesPulmonDB()]
#' @family pulmonDB

annotationPulmonDB = function(id,output = "contrast"){
  #message("Connecting to PulmonDB")
  a <- Sys.time()

  mydb = dbConnect(MySQL(),
                   user="guest",
                   password="pulmonDBguest",
                   dbname="expdata_hsapi_ipf",
                   host="132.248.248.114")

  message("Connecting to PulmonDB")
#132.248.248.114

  sql = "SELECT * from condition_definition"

  sqlref = 'SELECT
  sc.contrast_name, cd.condition_node_name, csr.value,  cd.cond_property_id,
  e.experiment_access_id, p.platform_name
  from sample_contrast as sc
  INNER JOIN condition_specification_of_ref_sample as csr ON sc.ref_sample_fk = csr.sample_fk
  INNER JOIN condition_definition as cd ON csr.cond_property_fk = cd.cond_property_id
  INNER JOIN sample as s ON sc.test_sample_fk = s.sample_id
  INNER JOIN experiment as e ON s.experiment_fk = e.experiment_id
  INNER JOIN array as a ON e.experiment_id = a.experiment_fk
  INNER JOIN platform as p ON a.platform_fk = p.platform_id
  WHERE (e.experiment_access_id IN ("'

  sqlcon= 'SELECT
  sc.contrast_name, cd.condition_node_name, csc.delta_value, cd.cond_property_id
  from sample_contrast as sc
  INNER JOIN condition_specification_of_contrast as csc ON sc.contrast_id = csc.contrast_fk
  INNER JOIN condition_definition as cd ON csc.cond_property_fk = cd.cond_property_id
  INNER JOIN sample as s ON sc.test_sample_fk = s.sample_id
  INNER JOIN experiment as e ON s.experiment_fk = experiment_id
  where (csc.delta_value NOT IN (-1))
  AND (e.experiment_access_id IN ("'

  rs = suppressWarnings(dbSendQuery(mydb,sql))
  data = fetch(rs, n=-1)
  #message("Data downloaded...")

  finalsql=paste(sqlref,
                 paste(id,collapse='","'),'"))',
                 sep = "")
  rs = suppressWarnings(dbSendQuery(mydb,finalsql))
  anno_ref = fetch(rs, n=-1)

  finalsql=paste(sqlcon,
                 paste(id,collapse='","'),'"))',
                 sep = "")
  rs = suppressWarnings(dbSendQuery(mydb,finalsql))
  anno_con = fetch(rs, n=-1)

  suppressWarnings(dbDisconnect(mydb))


  #############
  data = data[-c(185,195,197),]

  df = data[,c(1,3)]

  family = as.list(df$parent_node_id)
  names(family) = df$cond_property_id

  onto = suppressWarnings(ontologyIndex::ontology_index(parents = family))

  fa = data.frame()

  for (i in 1:length(family)){
    fa[i,"cond"] = names(family)[i]
    fa[i,"parent"] = paste(ontologyIndex::get_ancestors(onto,names(family)[i])[2], collapse = ",")
    #fa[i,"kids"] = paste(get_descendants(onto,names(family)[i]), collapse = ",")
  }

  k = data.frame()
  fau = unique(fa$parent)
  names(fau) <- fau

  fau = fau[-which(fau %in% c("10","11","160","NA"))]
  fau["9"] = "9"

  for (i in 1:length(fau)){
    k[i,"parent"] = fau[i]
    k[i,"kids"] = paste(ontologyIndex::get_descendants(onto,fau[i]), collapse = ",")
  }

  child = vector()
  parent = vector()

  for (i in 1:length(fau)){
    child = c(child,ontologyIndex::get_descendants(onto,fau[i]))
    parent = c(parent,rep(fau[i],length(ontologyIndex::get_descendants(onto,fau[i]))))
  }

  family = data.frame(child,parent)

  #############
  ## Per sample
  dicc = data[,2]
  names(dicc) = data[,1]

  # funcion para regresar matrix de sample vs condition
  pivot.anno <- function(anno){
    da = merge(anno,family,by.x = "cond_property_id",by.y = "child")[,-3]
    s = as.character(da[which(da$value!=1),1])
    s =  suppressMessages(plyr::revalue(s,dicc))
    s = paste(s,da[which(da$value!=1),3],sep = ":")
    da[which(da$value!=1),1] = s

    s = as.character(da[which(da$delta_value!=1),1])
    s =  suppressMessages(plyr::revalue(s,dicc))
    s = paste(s,da[which(da$delta_value!=1),3],sep = ":")
    da[which(da$delta_value!=1),1] = s

    d = suppressMessages(da %>%
      group_by(contrast_name,parent) %>%
      dplyr::summarise(kids = last(cond_property_id))) # alternative use nth(,1))

    ta = tidyr::spread(data = d,
                key = "parent",
                value = "kids")
    return(ta)
  }

  # funcion para sustituir los numeros por nombres
  anno.names = function(a_data){
    mref =  suppressMessages(sapply(1:ncol(a_data), function(x) plyr::revalue(as.character(a_data[,x]),dicc)))
    colnames(mref) = suppressMessages(plyr::revalue(colnames(a_data),dicc))
    rownames(mref) = mref[,1]
    return(mref[,-1])
  }

  # Se sobre escribe la matrix de ref con los datos de Contrasts
  ref <- suppressMessages(pivot.anno(anno_ref)) # se obtiene para tener datos faltantes
  con <- suppressMessages(pivot.anno(anno_con))

  sim = colnames(ref)[which(colnames(ref) %in% colnames(con))]
  for (i in 1:length(sim)){
    c = con[!is.na(con[,sim[i]]),]
    ref[ref$contrast_name %in% c$contrast_name,sim[i]] <- con[!is.na(con[,sim[i]]),sim[i]] # read::type_convert()
  }
  #Matrix con annotacion de los test
  con = as.data.frame(ref)
  con = anno.names(con)

  #Matrix con annotacion de las ref
  ref = pivot.anno(anno_ref)
  ref = as.data.frame(ref)
  ref = anno.names(ref)

  data_anno = sapply(colnames(ref),
                     function(x) paste(con[,x],ref[,x],sep = "_vs_"))
  data_anno <- data.frame(data_anno)
  data_anno[,'gsm'] <- rownames(ref)
  gse_gpl <- unique(
    anno_ref[,c("contrast_name","experiment_access_id","platform_name")])

  gse_gpl <- as_tibble(gse_gpl) %>%
    dplyr::group_by(contrast_name) %>%
    suppressMessages(dplyr::summarise(dplyr::first(platform_name), dplyr::first(experiment_access_id)))

  data_anno <- merge(data_anno,gse_gpl,by.x="gsm",by.y="contrast_name")
  rownames(data_anno) <- data_anno[,"gsm"]
  data_anno <- data_anno[,-1]
  colnames(data_anno)[ncol(data_anno)] <- "GSE"
  colnames(data_anno)[ncol(data_anno)-1] <- "PLATFORM"

  message("Time of processing ",Sys.time()-a)
  message("Annotation downloaded")
  ids = paste(id, collapse = " , ")
  message(paste(length(id),"GSE:",ids))
  cn <- paste(colnames(data_anno),collapse = " , ")
  message(paste(dim(data_anno)[2],"Features annotated:",cn))


    if (output == "contrast") {
      message(paste(dim(data_anno)[1],"Contrasts"))
      return(data_anno)}
    if (output == "sample") {

      rownames(con) = stringr::str_extract(rownames(con),"GSM[0-9]*")
      rownames(ref) = stringr::str_extract(stringr::str_extract(rownames(ref),"-GSM[0-9]*"),"GSM[0-9]*")
      ref = unique(ref)

      #l = list(test = con,
      #         ref = ref)
      data_anno = rbind(con,ref)

      message(paste(dim(data_anno)[1],"Samples"))
      return(data_anno)}



}

