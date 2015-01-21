// Kmean Clustering to find obstacle based on occmap
//

#include "OccMap.h"
#include <cassert>

inline double OccMap::norm(int x1, int y1, int x2, int y2) {
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

inline double OccMap::norm(double x1, double y1, double x2, double y2) {
  return (double)sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

int OccMap::kmean_clustering(void) {
  vector<grid_ij> good_pt;
  vector<int> cluster;
  int i = 0, j = 0;
  for (int cnt = 0; cnt < grid_num; cnt++) {
    if (grid[cnt] > obs_log_p) {
      i = cnt % map_size;
      j = (cnt - i) / map_size;
      grid_ij new_pt = {i, j, grid[cnt]};
      good_pt.push_back(new_pt);
    }
  }
  // return 0 obstacles
  if (good_pt.size() == 0) {
    nOb = 0;
    return 1;
  }
  else
    cluster.resize(good_pt.size());

  int r = 0;
  // Random init mean from points
  srand(time(0));
  for (int cnt = 0; cnt < maxObstacleClusters; cnt++) {
    r = (rand() % good_pt.size());
    means[cnt] = good_pt[r];
    means_new[cnt] = good_pt[r];
  }


    // iteration to cluser points
  bool changed = false;
  int iteration = 0, minindex = -1, clusterIdx = 0, maxIteration = 15;
  do {
    iteration ++;

    changed = false;
    for (int it = 0; it < good_pt.size(); it++) {
      //      cout << it << ' ' << good_pt.size() << endl;
      double mindist = 100000000;
      minindex = -1;
      for (int mit = 0; mit <= means.size(); mit++) {
        double dist = norm(good_pt[it].i, good_pt[it].j, means[mit].i, means[mit].j);
        if (dist < mindist) {
          mindist = dist;
          minindex = mit;
        }
      }
      cluster[it] = minindex;
    }

    // init means_new
    for (int cnt = 0; cnt < maxObstacleClusters; cnt++) {
      means_new[cnt].i = 0;
      means_new[cnt].j = 0;
      means_new_counter[cnt] = 0;
    } 
    // calculate new mean
    for (int cnt = 0; cnt < good_pt.size(); cnt ++) {
      clusterIdx = cluster[cnt];     
      means_new_counter[clusterIdx]++;
      means_new[clusterIdx].i += good_pt[cnt].i;
      means_new[clusterIdx].j += good_pt[cnt].j;
    }

    for (int cnt = 0; cnt < maxObstacleClusters; cnt++) {
      // if this cluster contain zero elements, regenerate
      if (means_new_counter[cnt]  == 0) {
        r = (rand() % good_pt.size());
        means_new[cnt] = good_pt[r];
      }
      else {
        means_new[cnt].i /= means_new_counter[cnt];
        means_new[cnt].j /= means_new_counter[cnt];
      }
      if ((means[cnt].i != means_new[cnt].i) || (means[cnt].j != means_new[cnt].j)) {
        changed = true; 
      }
      means[cnt] = means_new[cnt];
    }    
  }
  while (changed && iteration < maxIteration);

  nOb = maxObstacleClusters;
  vector<obstacle> obs_cluster;
  obs_cluster.resize(nOb);
  for (int cnt = 0; cnt < nOb; cnt++) {
    obstacle new_ob;
    // Get Centroid
    new_ob.centroid_y = rx * resolution - means[cnt].i * resolution;
    new_ob.centroid_x = ry * resolution - means[cnt].j * resolution;
    double dist = 0, minDist = 10000000, angle = 0, minAngle = M_PI, maxAngle = -M_PI;
    int nearestIdx = 0;
    double x = 0, y = 0;
    for (int iter = 0; iter < cluster.size(); iter++) {
      if (cluster[iter] == cnt) {
        x = ry * resolution - good_pt[iter].j * resolution;
        y = rx * resolution - good_pt[iter].i * resolution;
        dist = norm(x, y, odom_x, odom_y);
        if (dist < minDist) {
          minDist = dist;
          nearestIdx = iter;
        }
        angle = atan2(x, y);
        if (x < 0 && y < 0) 
          angle += 2 * M_PI;
        minAngle = min(minAngle, angle);
        maxAngle = max(maxAngle, angle);
      }
    }
    minAngle += odom_a;
    maxAngle += odom_a;
    new_ob.left_angle_range = minAngle;
    new_ob.right_angle_range = maxAngle;
    new_ob.nearest_y = rx * resolution - good_pt[nearestIdx].i * resolution;
    new_ob.nearest_x = ry * resolution - good_pt[nearestIdx].j * resolution;
    new_ob.nearest_dist = minDist;
    obs_cluster[cnt] = new_ob;
  }
  // check if obstacle overlays

  for (int cnt = 0; cnt < maxObstacleClusters; cnt++)
    obCheck[cnt] = 0;
  for (int i = 0; i < maxObstacleClusters; i++)
    for (int j = i+1; j < maxObstacleClusters; j++) {
      if (obCheck[i] == 1 or obCheck[j] == 1)
        continue;
      if ((abs(obs_cluster[i].left_angle_range - obs_cluster[j].left_angle_range) < 0.1) ||
        (abs(obs_cluster[i].right_angle_range - obs_cluster[j].right_angle_range) < 0.1)) {
        // merge to one obstacle
          nOb--;
          if (obs_cluster[j].nearest_dist < obs_cluster[i].nearest_dist)
            obCheck[i] = 1;
          else
            obCheck[j] = 1;
      }
    }

  int good_obstacle = 0;
  for (int cnt = 0; cnt < maxObstacleClusters; cnt++)
    if (obCheck[cnt] != 1)
      obs[good_obstacle++] = obs_cluster[cnt];
  assert(good_obstacle == nOb);

  return 1;
}