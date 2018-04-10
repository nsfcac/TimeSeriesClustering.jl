#


# convert Euro to US dollars
# introduced because the clusters generated by the python script are in EUR for GER
function get_EUR_to_USD(region::String)
   if region =="GER"
     ret = 1.109729
   else
     ret =1
   end
   return ret
end

function load_pricedata(region::String)
  wor_dir = pwd()
  cd(dirname(@__FILE__)) # change working directory to current file
  if region =="CA"
    region_str = ""
    region_data = normpath(joinpath(pwd(),"..","..","data","el_prices","ca_2015_orig.txt"))
  elseif region == "GER"
    region_str = "GER_"
    region_data = normpath(joinpath(pwd(),"..","..","data","el_prices","GER_2015_elPrice.txt"))
  else
    error("Region ",region," not defined.")
  end
  data_orig = Array(readtable(region_data, separator = '\t', header = false))
  data_orig_daily = reshape(data_orig,24,365)
  cd(wor_dir) # change working directory to old previous file's dir
  return data_orig_daily
end #load_pricedata


  """
  function sort_centers()
  centers: hours x days e.g.[24x9] 
  weights: days [e.g. 9], unsorted 
   sorts the centers by weights
  """
function sort_centers(centers::Array,weights::Array)
  i_w = sortperm(-weights)   # large to small (-)
  weights_sorted = weights[i_w]
  centers_sorted = centers[:,i_w]
  return centers_sorted, weights_sorted
end # function

##
# z-normalize data with mean and sdv by hour
# data: input format: (1st dimension: 24 hours, 2nd dimension: # of days)
# sequence: sequence based scaling - hourly is disregarded
#  hourly: true means univariate scaling: each hour is scaled seperately. False means one mean and standard deviation for the full data set.

function z_normalize(data;hourly=true,sequence=false)
  if sequence
    seq_mean = zeros(size(data)[2])
    seq_sdv = zeros(size(data)[2])
    data_norm = zeros(size(data)) 
    for i=1:size(data)[2]
      seq_mean[i] = mean(data[:,i])
      seq_sdv[i] = std(data[:,i])
      isnan(seq_sdv[i]) &&  (seq_sdv[i] =1)
      data_norm[:,i] = data[:,i] - seq_mean[i]
      data_norm[:,i] = data_norm[:,i]/seq_sdv[i]
    end
    return data_norm,seq_mean,seq_sdv
  else #no sequence
    hourly_mean = zeros(size(data)[1])
    hourly_sdv = zeros(size(data)[1])
    data_norm = zeros(size(data)) 
    if hourly # alternatively, use mean_and_std() and zscore() from StatsBase.jl
      for i=1:size(data)[1]
        hourly_mean[i] = mean(data[i,:])
        hourly_sdv[i] = std(data[i,:])
        isnan(hourly_sdv[i]) &&  (hourly_sdv[i] =1)
        data_norm[i,:] = data[i,:] - hourly_mean[i]
        data_norm[i,:] = data_norm[i,:]/hourly_sdv[i]
      end
    else # hourly = false
      hourly_mean = mean(data)*ones(size(data)[1])
      hourly_sdv = std(data)*ones(size(data)[1])
      data_norm = (data-hourly_mean[1])/hourly_sdv[1]
    end
    return data_norm, hourly_mean, hourly_sdv
  end
end # function z_normalize

##
# undo z-normalization data with mean and sdv by hour
# normalized data: input format: (1st dimension: 24 hours, 2nd dimension: # of days)
# hourly_mean ; 24 hour vector with hourly means
# hourly_sdv; 24 hour vector with hourly standard deviations

function undo_z_normalize(data_norm, mn, sdv; idx=[])
  if size(data_norm,1) == size(mn,1) # hourly
    data = data_norm .* sdv + mn * ones(size(data_norm)[2])'
    return data
  elseif !isempty(idx) && size(data_norm,2) == maximum(idx) # sequence based
    # we obtain mean and sdv for each day, but need mean and sdv for each centroid - take average mean and sdv for each cluster
    summed_mean = zeros(size(data_norm,2)) 
    summed_sdv = zeros(size(data_norm,2))
    for k=1:size(data_norm,2)
      mn_temp = mn[idx.==k]
      sdv_temp = sdv[idx.==k]
      summed_mean[k] = sum(mn_temp)/length(mn_temp) 
      summed_sdv[k] = sum(sdv_temp)/length(sdv_temp)
    end
    data = data_norm * Diagonal(summed_sdv) +  ones(size(data_norm,1)) * summed_mean'
    return data
  elseif isempty(idx)
    error("no idx provided in undo_z_normalize")
  end
end

# calculates the minimum and maximum allowed indices for a lxl windowed matrix
# for the sakoe chiba band (see Sakoe Chiba, 1978).
# Input: radius r, such that |i(k)-j(k)| <= r
# length l: dimension 2 of the matrix

function sakoe_chiba_band(r::Int,l::Int)
  i2min = Int[]
  i2max = Int[]
  for i=1:l
    push!(i2min,max(1,i-r))
    push!(i2max,min(l,i+r))
  end
  return i2min, i2max
end


