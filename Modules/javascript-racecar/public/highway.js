document.addEventListener("DOMContentLoaded", function(event) {
  const DEG_PER_RAD = 180 / Math.PI;

  const reference_vehicle = "tri1";
  //
  const vicon2pose = p => {
    return [p.translation[0] / 1e3, p.translation[1] / 1e3, p.rotation[2]];
  };

  ///////////////////////////
  // Identifying the SVG size
  const environment_div = document.getElementById("topdown");
  const environment_svg = document.getElementById("environment");
  var viewBox = environment_svg.getAttribute("viewBox").split(" ");
  var X_SVG_MIN = parseFloat(viewBox[0]);
  var Y_SVG_MIN = parseFloat(viewBox[1]);
  var X_SVG_SZ = parseFloat(viewBox[2]);
  var Y_SVG_SZ = parseFloat(viewBox[3]);

  // Sizing the canvas
  const environment_canvas = document.getElementById("stage");
  var environment_ctx = false;
  var X_CANVAS_SZ, Y_CANVAS_SZ;
  const X_CANVAS_MIN = 0;
  const Y_CANVAS_MIN = 0;

  const svg2canvas_sz = s => {
    return [(s[0] * X_CANVAS_SZ) / X_SVG_SZ, (s[1] * Y_CANVAS_SZ) / Y_SVG_SZ];
  };
  const svg2canvas = p => {
    return [
      (X_CANVAS_SZ * (p[0] - X_SVG_MIN)) / X_SVG_SZ + X_CANVAS_MIN,
      (Y_CANVAS_SZ * (p[1] - Y_SVG_MIN)) / Y_SVG_SZ + Y_CANVAS_MIN,
      p[2]
    ];
  };
  // Flip X and Y
  const coord2svg = p => {
    return [p[1], p[0], Math.PI / 2 - p[2]];
  };
  const svg2polypoints = pt => {
    return pt.slice(0, 2).join();
  };
  // End of dimensions
  ///////////////////////////

  ///////////////////
  // Process messages, and hold on to the current values
  let cur = {};
  let rendered_message = true;
  // Utilize parsing library
  const munpack = msgpack5().decode;
  //
  const port = 9001;
  const ws = new window.WebSocket(
    "ws://" + window.location.hostname + ":" + port
  );
  ws.binaryType = "arraybuffer";
  ws.onmessage = e => {
    let msg = munpack(new Uint8Array(e.data));
    Object.assign(cur, msg);
    // console.log(msg);
    rendered_message = false;
  };
  // Process messages
  ///////////////////

  const requestElementsSVG = (el_type, el_class, n_el) => {
    let els_existing = environment_svg.getElementsByClassName(el_class);
    // Make the unneeded items invisible
    for (let i_unused = n_el; i_unused < els_existing.length; i_unused++) {
      // TODO: Maybe style?
      els_existing.item(i_unused).setAttributeNS(null, "display", "none");
      // environment_svg.removeChild(els_existing.item(i_unused));
    }
    // Create new ones
    for (let i_el = els_existing.length; i_el < n_el; i_el++) {
      let el = document.createElementNS("http://www.w3.org/2000/svg", el_type);
      // Set the appropriate class
      el.setAttributeNS(null, "class", el_class);
      // Add to the tree
      environment_svg.appendChild(el);
    }
    // Form the array interface, setting th evisibility
    // let els = [];
    for (let i_el = 0; i_el < n_el; i_el++) {
      let el = els_existing.item(i_el);
      el.setAttributeNS(null, "display", "initial");
      // els.push(el);
    }
    // return els;
    return els_existing;
  };

  ///////////////////////////
  // Animation loop: Draw items
  // Update mapping of function -> timestamp
  let visualizers = new Map();
  const animate = () => {
    // Call this function, again
    requestAnimationFrame(animate);
    // No new messages, so simply return
    if (rendered_message) {
      return;
    }
    // const t_render = Date.now();
    // Draw the current items
    // Call the function, with optional previous information, so that we do not render too quickly
    visualizers.forEach((info_prev, fn) => {
      const info = fn(cur, info_prev);
      visualizers.set(fn, info);
    });
    rendered_message = true;
  };
  animate();
  // Recompute upon resize
  window.addEventListener("resize", () => {
    rendered_message = false;
    environment_ctx = false;
  });
  ///////////////////////////

  // Handle changes in the viewer boundaries
  const update_view = (msg, info_previous) => {
    const debug = msg.debug;
    if (debug && debug.viewBox) {
      const viewBoxNew = debug.viewBox;
      const viewbox_changed = viewBoxNew.reduce((eq, v, i) => {
        return eq || v !== viewBox[i];
      }, false);
      if (viewbox_changed) {
        // NOTE: Must flip the coordinates...
        X_SVG_MIN = parseFloat(viewBoxNew[1]);
        Y_SVG_MIN = parseFloat(viewBoxNew[0]);
        X_SVG_SZ = parseFloat(viewBoxNew[3]);
        Y_SVG_SZ = parseFloat(viewBoxNew[2]);
        environment_svg.setAttribute(
          "viewBox",
          X_SVG_MIN + " " + Y_SVG_MIN + " " + X_SVG_SZ + " " + Y_SVG_SZ
        );
        environment_ctx = false;
      }
    }
    // Check our sizes
    if (!environment_ctx) {
      const rect = environment_svg.getBoundingClientRect();
      X_CANVAS_SZ = environment_canvas.width = rect.width;
      Y_CANVAS_SZ = environment_canvas.height = rect.height;
      environment_ctx = environment_canvas.getContext("2d");
    }
    return true;
  };
  visualizers.set(update_view, false);

  const update_road = (msg, info_previous) => {
    const planner = msg.planner;
    if (!planner) {
      return;
    }

    // Grab the SVG of each lane
    var lanes_els = environment_svg.getElementsByClassName("lane");

    if (planner.paths) {
      const lanes = planner.paths;
      // Iterate the names of the lanes
      Object.keys(lanes).forEach((name, ilane) => {
        const l = lanes[name];
        const points = l["points"]
          .map(coord2svg)
          .map(svg2polypoints)
          .join(" ");
        const lane_id = "lane_" + name;
        var el = lanes_els.namedItem(lane_id);
        if (!el) {
          el = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "polyline"
          );
          el.setAttributeNS(null, "id", lane_id);
          el.setAttributeNS(null, "class", "lane");
          el.style.fill = "none";
          el.style.stroke = "#0F0";
          el.style.strokeWidth = "0.1";
          el.style.opacity = "0.3";
          // el.setAttributeNS(null, 'marker-start', 'url(#arrow)');
          el.setAttributeNS(null, "marker-end", "url(#marker-arrow)");
          if (name.startsWith("turn_")) {
            el.setAttributeNS(null, "marker-mid", "url(#marker-dot)");
          }
          environment_svg.appendChild(el);
        }
        el.setAttributeNS(null, "points", points);
      });
    } // end of checking for lanes

    // Try highways
    if (!planner.highways) {
      return;
    }
    // console.log(planner.highways);
    const hw = planner.highways["i95"];
    // console.log(hw);
    if (!hw) {
      return;
    }
    // Get the pose of the vehicle
    const debug_info = msg.debug;
    if (!debug_info || !debug_info["reference_vehicle"]) {
      return;
    }
    const vehicles = msg.vicon;
    if (!vehicles) {
      return;
    }
    //
    const reference_pose = vicon2pose(vehicles[reference_vehicle]);
    let i_marker_ref = Math.floor(reference_pose[0] / hw.marker_interval);
    i_marker_ref = Math.max(0, Math.min(i_marker_ref, hw.n_markers - 1));
    const marker_ref = hw.markers[i_marker_ref];
    const lane_width = marker_ref.lane_width || hw.lane_width;
    const marker_interval = hw.marker_interval;
    //
    let waypoints_lanes = [];
    // Find the surrounding markers
    const N_MARKERS_PREV = 1;
    const N_MARKERS_NEXT = 1;
    for (
      let d_marker = -N_MARKERS_PREV;
      d_marker <= N_MARKERS_NEXT;
      d_marker++
    ) {
      const i_marker = i_marker_ref + d_marker;
      if (i_marker < 0 || i_marker >= hw.n_markers) {
        continue;
      }
      const marker = hw.markers[i_marker];
      // console.log("marker", marker);
      const x_start = i_marker * marker_interval - reference_pose[0];

      let lanes_running = marker.lanes.slice(0);
      let distances_running = lanes_running.map(() => x_start);
      // Add events
      const marker_events = marker["events"];
      marker_events.forEach(evt => {
        const evt_dist = evt[0] - reference_pose[0];
        const evt_name = evt[1];
        const evt_info = evt[2];
        // console.log("evt_name", evt_name, evt_dist, evt_info);
        if (evt_name == "add_lane") {
          if (evt_info["on_far_side"]) {
            lanes_running.unshift(lanes_running[0] + 1);
            distances_running.unshift(evt_dist);
          } else {
            lanes_running.push(lanes_running[lanes_running.length - 1] - 1);
            distances_running.push(evt_dist);
          }
        } else if (evt_name == "del_lane") {
          const y = evt_info["on_far_side"]
            ? lanes_running.shift()
            : lanes_running.pop();
          const x_begin = evt_info["on_far_side"]
            ? distances_running.shift()
            : distances_running.pop();
          waypoints_lanes.push([
            [x_begin, y * lane_width],
            [evt_dist, y * lane_width]
          ]);
          // console.log(x_begin, evt_dist);
        }
      });

      // Duplicate the last one, in order to have an end point
      const lanes_final = lanes_running.map((y, i) => {
        return [
          [distances_running[i], y * lane_width],
          [x_start + marker_interval, y * lane_width]
        ];
      });
      waypoints_lanes.push(...lanes_final);

      const is_current = d_marker == 0;
    } // For surrounding markers
    let polypoints_per_wp = waypoints_lanes.map(wps => {
      // Form the visualization
      return wps
        .map(coord2svg)
        .map(svg2polypoints)
        .join(" ");
    });
    // Element Type, id, class
    let el_lanes = requestElementsSVG(
      "polyline",
      "lane",
      polypoints_per_wp.length
    );
    polypoints_per_wp.forEach((lane_polypoints, i_wp) => {
      // console.log(i_wp, lane_polypoints);
      el = el_lanes.item(i_wp);
      el.setAttributeNS(null, "points", lane_polypoints);
    });
  };
  // Add to the processor
  visualizers.set(update_road, false);

  const update_poses = (msg, info_previous) => {
    const vehicles = msg.vicon;
    if (!vehicles) {
      return;
    }
    // Check if we have seen this frame, before
    const frame = vehicles.frame;
    if (frame === info_previous) {
      return;
    }
    delete vehicles.frame;

    const debug_info = msg.debug;
    let frame_of_reference = false;
    if (debug_info && debug_info["reference_vehicle"]) {
      frame_of_reference = vicon2pose(vehicles[reference_vehicle]);
    }

    // SVG
    Object.keys(vehicles).forEach((vehicle_name, ivehicle) => {
      const vehicle = vehicles[vehicle_name];
      const vehicle_el_id = "vehicle_" + vehicle_name;
      let vehicle_el = document.getElementById(vehicle_el_id);
      if (!vehicle_el) {
        vehicle_el = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "use"
        );
        vehicle_el.setAttributeNS(
          "http://www.w3.org/1999/xlink",
          "xlink:href",
          // "basevehicle"
          "#automobile"
        );
        vehicle_el.setAttributeNS(null, "id", vehicle_el_id);
        vehicle_el.setAttributeNS(null, "class", "vehicle");
        environment_svg.appendChild(vehicle_el);
      }
      // Update the properties
      let pose = vicon2pose(vehicle);
      if (frame_of_reference) {
        // NOTE: For highway, do not use angles, so OK
        pose[0] = pose[0] - frame_of_reference[0];
      }
      const coord_svg = coord2svg(pose);
      vehicle_el.setAttributeNS(null, "x", coord_svg[0]);
      vehicle_el.setAttributeNS(null, "y", coord_svg[1]);
      const tfm_vel =
        "rotate(" +
        [coord_svg[2] * DEG_PER_RAD, coord_svg[0], coord_svg[1]].join() +
        ")";
      vehicle_el.setAttributeNS(null, "transform", tfm_vel);
    });
    // THREE.js
    // while (vehicles.length > veh_boxes.length) {
    //   const veh = veh_mesh.clone();
    //   scene.add(veh);
    //   veh_boxes.push(veh);
    // }
    // while (vehicles.length < veh_boxes.length) {
    //   scene.remove(veh_boxes.pop());
    // }
    // vehicles.forEach((v, i) => {
    //   const veh = veh_boxes[i];
    //   veh.position.x = v[0];
    //   veh.position.y = v[1];
    //   veh.rotation.z = v[2];
    // });
    return frame;
  };
  // Add to the processor
  visualizers.set(update_poses, false);

  const update_control = (msg, info_previous) => {
    const ctrl = msg.control;
    if (!ctrl) {
      return;
    }
    const id_robot = ctrl.id;
    const vehicles = msg.vicon;
    if (!vehicles) {
      return;
    }
    const debug_info = msg.debug;
    let frame_of_reference = false;
    if (debug_info && debug_info["reference_vehicle"]) {
      frame_of_reference = vicon2pose(vehicles[reference_vehicle]);
    }
    //
    const reference_pose = vicon2pose(vehicles[reference_vehicle]);

    // Lookahead
    const p_lookahead = ctrl.p_lookahead;
    if (p_lookahead) {
      var pla_el = document.getElementById("lookahead_" + id_robot);
      if (!pla_el) {
        pla_el = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "circle"
        );
        pla_el.setAttributeNS(null, "id", "lookahead_" + id_robot);
        pla_el.setAttributeNS(null, "r", 0.05);
        pla_el.setAttributeNS(null, "class", "lookahead");
        environment_svg.appendChild(pla_el);
      }
      let p_la = p_lookahead.slice(0);
      if (frame_of_reference) {
        p_la[0] -= frame_of_reference[0];
      }
      p_la = coord2svg(p_la);
      pla_el.setAttributeNS(null, "cx", p_la[0]);
      pla_el.setAttributeNS(null, "cy", p_la[1]);
    }

    // Near
    const p_near = ctrl.p_path;
    if (p_near) {
      var pn_el = document.getElementById("near_" + id_robot);
      if (!pn_el) {
        pn_el = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "circle"
        );
        pn_el.setAttributeNS(null, "id", "near_" + id_robot);
        pn_el.setAttributeNS(null, "r", 0.05);
        pn_el.setAttributeNS(null, "class", "near");
        environment_svg.appendChild(pn_el);
      }
      let p_n = p_near.slice(0);
      if (frame_of_reference) {
        p_n[0] -= frame_of_reference[0];
      }
      p_n = coord2svg(p_n);
      pn_el.setAttributeNS(null, "cx", p_n[0]);
      pn_el.setAttributeNS(null, "cy", p_n[1]);
    }
    return false;
  };
  // Add to the processor
  visualizers.set(update_control, false);
});
