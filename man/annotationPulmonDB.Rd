% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotationPulmonDB.R
\name{annotationPulmonDB}
\alias{annotationPulmonDB}
\title{Annotation from PulmonDB}
\source{
\url{http://pulmondb.liigh.unam.mx/}
}
\usage{
annotationPulmonDB(id, output = "contrast")
}
\arguments{
\item{id}{A value or character vector with GSEs (GEO id).}

\item{output}{"contrast" or "sample". Default is "contrast" but it also can
be changed to return annotation per "sample"}
}
\value{
This is the result.
}
\description{
This gives you manually curated annotation for all GSEs available
in PulmonDB.
}
\details{
Details.
PulmonDB has contrast values (test_condition vs reference), which
curated annotation can be returned using annotationPulmonDB(),
default option is annotation by "contrast" and it will give you
a string with the test and the reference annotation separated by
"_vs_" (EMPHYSEMA_vs_HEALTHY/CONTROL).

It also has the opption to retrieve annotation per sample using
the condition output = "sample".

Sometimes the feature annotated can be empty when two o more
GSEs are downloaded. Each GSE has different
annotation and not allways all annotation features are available.
}
\examples{
## Annotation per contrast
annotationPulmonDB("GSE27536")
annotationPulmonDB("GSE27536","contrast")
## Annotation per sample
annotationPulmonDB(c("GSE101286","GSE1122"),"sample")


}
\seealso{
[genesPulmonDB()]
}
\concept{pulmonDB}
