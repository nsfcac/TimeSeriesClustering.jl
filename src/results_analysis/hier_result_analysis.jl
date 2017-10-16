 # imports
push!(LOAD_PATH, normpath(joinpath(pwd(),".."))) #adds the location of ClustForOpt to the LOAD_PATH
push!(LOAD_PATH, "/data/cees/hteich/clustering/src")
using ClustForOpt
using JLD2 # Much faster than JLD (50s vs 20min)
using FileIO

using PyPlot
using DataFrames
plt = PyPlot

 # read parameters
param=DataFrame()
try
  param = readtable(joinpath("outfiles","parameters.txt"))
catch
  error("No input file parameters.txt exists in folder outfiles.")
end

n_clust_min=param[:n_clust_min][1]
n_clust_max=param[:n_clust_max][1]
n_hier=param[:n_hier][1]
iterations=param[:iterations][1]
region=param[:region][1]

n_clust_ar = collect(n_clust_min:n_clust_max)
 
# read in original data
data_orig_daily = load_pricedata(region)
seq = data_orig_daily[:,1:365]  # do not load as sequence

 # opt problem
problem_type = "battery"


 # load saved JLD data
saved_data_dict= load("outfiles/aggregated_results_hier_centroid.jld2")
 #unpack saved JLD data
 for (k,v) in saved_data_dict
   @eval $(Symbol(string(k,"_centroid"))) = $v
 end

 #set revenue to the chosen problem type
revenue_centroid=revenue_centroid[problem_type] 

 # load saved JLD data
saved_data_dict= load("outfiles/aggregated_results_hier_medoid.jld2")
 #unpack saved JLD data
 for (k,v) in saved_data_dict
   @eval $(Symbol(string(k,"_medoid"))) = $v
 end

 #set revenue to the chosen problem type
revenue_medoid=revenue_medoid[problem_type] 
 


 # Find best cost index - save
ind_mincost = findmin(cost_centroid,2)[2]  # along dimension 2
ind_mincost = reshape(ind_mincost,size(ind_mincost,1))
revenue_centroid_best = zeros(size(revenue_centroid,1))
for i=1:size(revenue_centroid,1)
    revenue_centroid_best[i]=revenue_centroid[ind_mincost[i]] 
end

 # Find best cost index - save
ind_mincost = findmin(cost_medoid,2)[2]  # along dimension 2
ind_mincost = reshape(ind_mincost,size(ind_mincost,1))
revenue_medoid_best = zeros(size(revenue_medoid,1))
for i=1:size(revenue_medoid,1)
    revenue_medoid_best[i]=revenue_medoid[ind_mincost[i]] 
end


# optimization on original data
revenue_orig_daily = sum(run_opt(problem_type,data_orig_daily,1,region,false));

 #### Figures #######
figure()
plt.plot(n_clust_ar,revenue_centroid_best[:]/1e6,lw=2,color="b",label="hier. centr.")
plt.plot(n_clust_ar,revenue_medoid_best[:]/1e6,lw=2,color="k",label="hier. medoid")
plt.plot(n_clust_ar,revenue_orig_daily/1e6*ones(length(n_clust_ar)),label="365 days",color="c",lw=3)
plt.legend()

 # function plot cost vs revenue  
function plot_cost_rev()
  figure()
  for i=1:length(n_clust_ar)
    plt.plot(cost[i,:],revenue[i,:]/1e6,".",label=string("k=",n_clust_ar[i]))
  end
  plt.title(string("cost vs revenue"))
  plt.legend()
  plt.xlabel("cost")
  plt.ylabel("revenue [mio EUR]")
end #function

 #plot_cost_rev()

"""
 # plot iterations and iterations
figure()
boxplot(iter[:,:]')
plt.title("iterations")

 # cumulative cost
 # TODO - random indice generator for k - generate many sample paths in this way

function plot_cum_cost(cost,k_ind,n_perm)
  cum_cost=zeros(size(cost,2),n_perm)
   #n_perm=20 # number of permutations
  figure()
  for i=1:n_perm
    cost_perm = cost[k_ind,:][randperm(size(cost,2))]
    for k=1:size(cost,2)
      cum_cost[k,i]=minimum(cost_perm[1:k])
    end
    plt.plot(cum_cost[:,i],color="grey",alpha=0.4)  
  end
  plt.xlabel("No. of trials")
  plt.ylabel("cost [clustering algorithm]")
  plt.title(string("k=",k_ind,", No. of permutations:",n_perm))
end # function

plot_cum_cost(cost,2,20)

figure()
boxplot(revenue')
plot(collect(1:length(n_clust_ar)),revenue_best,label="best cost")
plt.legend()
plt.ylabel("revenue")
"""

plt.show()