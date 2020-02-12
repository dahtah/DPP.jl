#Some code for partial projection ensembles, of mostly theoretical interest for
#now. 


mutable struct PPEnsemble <: AbstractLEnsemble
    Lopt :: AbstractLEnsemble
    Lproj :: ProjectionEnsemble
    M :: Matrix
    V :: Matrix
    α :: Float64
end

function PPEnsemble(M :: Matrix, V :: Matrix)
    @assert (size(M,1) == size(V,1))
    @assert (size(M,1) > size(V,2))
    Lproj = ProjectionEnsemble(V)
    #Orthogonalise (inefficient)
    Morth = (I-Lproj.U*Lproj.U')*(M*(I-Lproj.U*Lproj.U'))
    Lopt = FullRankEnsemble((Morth+Morth')/2)
    PPEnsemble(Lopt,Lproj,M,V,1.)
end

nitems(L::PPEnsemble) = nitems(L.Lopt)
maxrank(L::PPEnsemble) = min(nitems(L),maxrank(L.Lopt) + maxrank(L.Lproj))
min_items(L::PPEnsemble) = maxrank(L.Lproj)
logz(L::PPEnsemble) = logz(L.Lopt)
logz(L::PPEnsemble,k) = (k > min_items(L) ? logz(L.Lopt,k-min_items(L)) : 0.0)
function log_prob(L::PPEnsemble,ind,k::Int)
    m = min_items(L)
    @assert (length(ind)==k)
    if (k < m || m > maxrank(L))
        return -Inf
    else
        Laug = [L.α*L.M[ind,ind] L.Lproj.U[ind,:];
                L.Lproj.U[ind,:]' zeros(m,m)];
        logabsdet(Laug)[1] - logz(L,k)
    end
end

function log_prob(L::PPEnsemble,ind)
    m = min_items(L)
    k=length(ind)
    if (k < m || k > maxrank(L))
        return -Inf
    else
        Laug = [L.α*L.M[ind,ind] L.Lproj.U[ind,:];
                L.Lproj.U[ind,:]' zeros(m,m)];
        logabsdet(Laug)[1] - logz(L)
    end
end


function show(io::IO, e::PPEnsemble)
    println(io, "Partial projection DPP.")
    println(io,"Number of items in ground set : $(nitems(e)). Max. rank :
    $(maxrank(e))")
    println(io,"Rank of projective part : $(maxrank(e.Lproj))")
end

function rescale!(L::PPEnsemble,k)
    @assert min_items(L) < k <= maxrank(L)
    L.α = rescale!(L.Lopt,k-min_items(L));
end


function sample(L::PPEnsemble)
    r = maxrank(L.Lproj)
    λ = eigenvalues(L.Lopt)
    val = @.  λ / (1 + λ)
    ii = rand(length(val)) .< val
    sample_pdpp([L.Lproj.U L.Lopt.U[:,ii]])
end


function sample(L::PPEnsemble,k)
    @assert(k >= maxrank(L.Lproj))
    r = maxrank(L.Lproj)
    if (k>r)
        ii=collect(sample_diag_kdpp(L.Lopt,k-r))
        sample_pdpp([L.Lproj.U L.Lopt.U[:,ii]])
    else
        sample_pdpp(L.Lproj.U)
    end
end
