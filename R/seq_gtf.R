#' @title Get transcript sequences from GTF file and sequence info
#'
#' @description Given a GTF file (for transcript structure) and DNA sequences, return a DNAStringSet
#' of transcript sequences
#' @param gtf one of path to GTF file, or data frame representing a canonical GTF file.
#' @param seqs one of path to folder containing one FASTA file (\code{.fa} extension) for each 
#' chromosome in \code{gtf}, or named DNAStringSet containing one DNAString per chromosome in 
#' \code{gtf}, representing its sequence. In the latter case, \code{names(seqs)} should contain the
#' same entries as the \code{seqnames} (first) column of \code{gtf}.
#' @param exononly if \code{TRUE} (as it is by default), only create transcript sequences from the 
#' features labeled \code{exon} in \code{gtf}
#' @param idfield in the \code{attributes} column of \code{gtf}, what is the name of the field 
#' identifying transcripts? Should be character. Default \code{"transcript_id"}.
#' @param attrsep in the \code{attributes} column of \code{gtf}, how are attributes separated? 
#' Default \code{"; "}.
#' 
#' @export
#' @references \url{http://www.ensembl.org/info/website/upload/gff.html}
#' @return DNAStringSet containing transcript sequences, with names corresponding to \code{idfield}
#' in \code{gtf}
#' @examples \dontrun{
#'   require(Biostrings)
#'   load(url('http://biostat.jhsph.edu/~afrazee/chr22seq.rda'))
#'   data(gtf_dataframe)
#'   chr22_processed = seq_gtf(gtf_dataframe, chr22seq)
#' }
seq_gtf = function(gtf, seqs, exononly=TRUE, idfield="transcript_id", attrsep="; "){

    gtfClasses = c("character", "character", "character", "integer", "integer", "character", 
        "character", "character", "character")
    if(is.character(gtf)){
        # read transcript structure from file:s
        gtf_dat = read.table(gtf, sep="\t", as.is=TRUE, quote="", header=FALSE, comment.char="#", 
            nrows= -1, colClasses=gtfClasses)
    } else if(is.data.frame(gtf)){
        # do what we can to check whether gtf really does represent a canonical GTF
        stopifnot(ncol(gtf) == 9)
        if(!all(unlist(lapply(gtf, class)) == gtfClasses)){
            stop("one or more columns of gtf have the wrong class")
        }
        gtf_dat = gtf
        rm(gtf)
    } else {
        stop("gtf must be a file path or a data frame")
    }

    colnames(gtf_dat) = c("seqname", "source", "feature", "start", "end", "score", "strand", 
        "frame", "attributes")
    stopifnot(!any(is.na(gtf_dat$start)), !any(is.na(gtf_dat$end)))

    if(exononly){
        gtf_dat = gtf_dat[gtf_dat[,3]=="exon",]
    }

    # makes sure all chromosomes are present:
    chrs = unique(gtf_dat$seqname)
    if(is.character(seqs)){
        fafiles = list.files(seqs)
        lookingFor = paste0(chrs, '.fa')
    } else {
        fafiles = names(seqs)
        lookingFor = chrs
    }
    if(!(all(lookingFor %in% fafiles))){
        stop("all chromosomes in gtf must have corresponding sequences in seqs")
    }

    seqlist = lapply(chrs, function(chr){
        dftmp = gtf_dat[gtf_dat[,1]==chr,]
        if(is.character(seqs)){
            fullseq = readDNAStringSet(paste0(seqs, '/', chr, '.fa'))
        } else {
            fullseq = seqs[which(names(seqs) == chr)]
        }
        these_seqs = subseq(rep(fullseq, times=nrow(dftmp)), start=dftmp$start, end=dftmp$end)
        names(these_seqs) = getAttributeField(dftmp$attributes, idfield, attrsep=attrsep)
        these_seqs
    })

    full_list = do.call(c, seqlist)
    split_list = split(full_list, names(full_list))
    DNAStringSet(lapply(split_list, unlist)) #took 340 sec on whole human transcriptome hg19
}

