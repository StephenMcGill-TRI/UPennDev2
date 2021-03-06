/*
   C routines to access V4L2 camera
Author  : Daniel D. Lee <ddlee@seas.upenn.edu>, 05/10
: Stephen McGill 10/10
: Yida Zhang <yida@seas.upenn.edu> 05/13
*/

#include "v4l2.h"

static query_node *add_query_node(query_node *query, char *key,
                                  void *query_value,
                                  long unsigned int query_value_len) {
  query_node *new_node = malloc(sizeof(query_node));
  new_node->key = malloc(strlen(key));
  memcpy(new_node->key, key, strlen(key));

  new_node->value = malloc(query_value_len);
  memcpy(new_node->value, query_value, sizeof(query_value_len));
  new_node->next = query;
  return new_node;
}

static void release_node(query_node *query) {
  if (query == NULL) {
    return;
  }
  query_node *ptr = query;
  query_node *curp = NULL;
  while (ptr != NULL) {
    curp = ptr;
    ptr = ptr->next;
    void *key = curp->key;
    if (key) {
      free(key);
      curp->key = NULL;
    }
    if (curp->value) {
      free(curp->value);
      curp->value = NULL;
    }
    free(curp);
  }
}

static void *get_query_node(query_node *query, const char *key) {
  query_node *qptr = query;
  while (qptr != NULL) {
    if (strstr(qptr->key, key) != NULL) {
      return qptr->value;
    }
    qptr = qptr->next;
  }
  return NULL;
}

static int xioctl(int fd, int request, void *arg) {
  int r;
  do {
    r = ioctl(fd, request, arg);
    // fprintf(stderr, "Ret: %d, Errno: %d [EINTR: %d]\n", r, errno, EINTR);
  } while (r == -1 && errno == EINTR);
  return r;
}

int v4l2_query_menu(v4l2_device *vdev, struct v4l2_queryctrl *queryctrl) {
  struct v4l2_querymenu querymenu;

  querymenu.id = queryctrl->id;
  for (querymenu.index = queryctrl->minimum;
       querymenu.index <= queryctrl->maximum; querymenu.index++) {
    if (ioctl(vdev->fd, VIDIOC_QUERYMENU, &querymenu) == 0) {
      vdev->menu_map = add_query_node(vdev->menu_map, (char *)querymenu.name,
                                      (void *)&querymenu, sizeof(querymenu));
    } else
      fprintf(stderr, "Could not query menu %d\n", querymenu.index);
  }
  return 0;
}

int v4l2_query_ctrl(v4l2_device *vdev, unsigned int addr_begin,
                    unsigned int addr_end) {
  struct v4l2_queryctrl queryctrl;

  for (queryctrl.id = addr_begin; queryctrl.id < addr_end; queryctrl.id++) {
    if (ioctl(vdev->fd, VIDIOC_QUERYCTRL, &queryctrl) == -1) {
      if (errno == EINVAL)
        continue;
      else
        fprintf(stderr, "Could not query control %d\n", queryctrl.id);
    }

    fprintf(stdout, "queryctrl: \"%s\" 0x%x %d %d %d\n", queryctrl.name,
            queryctrl.id, queryctrl.minimum, queryctrl.maximum,
            queryctrl.default_value);
    fflush(stdout);

    switch (queryctrl.type) {
    case V4L2_CTRL_TYPE_MENU:
      v4l2_query_menu(vdev, &queryctrl);
    case V4L2_CTRL_TYPE_INTEGER:
    case V4L2_CTRL_TYPE_BOOLEAN:
    case V4L2_CTRL_TYPE_BUTTON:
      vdev->ctrl_map = add_query_node(vdev->ctrl_map, (char *)queryctrl.name,
                                      (void *)&queryctrl, sizeof(queryctrl));
      break;
    default:
      break;
    }
  }

  return 0;
}

int v4l2_error(const char *error_msg) {
  int x = errno;
  fprintf(stderr, "Err [%d]: %s\n", x, strerror(x));
  fprintf(stderr, "V4L2 error: %s\n", error_msg);
  return -2;
}

int v4l2_uninit_mmap(v4l2_device *vdev) {
  if ((vdev->buffer == NULL) || (vdev->buf_len == NULL)) {
    return 0;
  }
  int i;
  for (i = 0; i < NBUFFERS; i++) {
    void *buf = (void *)vdev->buffer[i];
    if (buf == NULL) {
      fprintf(stderr, "empty buffer");
      continue;
    } else if (munmap(buf, vdev->buf_len[i]) == -1) {
      return v4l2_error("munmap");
    }
  }
  free(vdev->buffer);
  vdev->buffer = NULL;
  free(vdev->buf_len);
  vdev->buf_len = NULL;
  free(vdev->buf_used);
  vdev->buf_used = NULL;
  return 0;
}

int v4l2_init_mmap(v4l2_device *vdev) {
  struct v4l2_requestbuffers req;
  req.count = NBUFFERS;
  req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  req.memory = V4L2_MEMORY_MMAP;
  if (xioctl(vdev->fd, VIDIOC_REQBUFS, &req)) {
    return v4l2_error("VIDIOC_REQBUFS");
  }
  if (req.count < NBUFFERS) {
    return v4l2_error("Insufficient buffer memory\n");
  }

  vdev->buffer = (void **)malloc(req.count * sizeof(void *));
  vdev->buf_len = (int *)calloc(req.count, sizeof(int));
  vdev->buf_used = (int *)calloc(req.count, sizeof(int));

  int i = 0;
  struct v4l2_buffer buf;
  for (i = 0; i < req.count; i++) {
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = i;
    if (xioctl(vdev->fd, VIDIOC_QUERYBUF, &buf) == -1) {
      return v4l2_error("VIDIOC_QUERYBUF");
    }
    vdev->buf_len[i] = buf.length;
    vdev->buffer[i] = mmap(NULL, /* start anywhere */
                           buf.length, PROT_READ | PROT_WRITE, /* required */
                           MAP_SHARED,                         /* recommended */
                           vdev->fd, buf.m.offset);
    if (vdev->buffer[i] == MAP_FAILED) {
      return v4l2_error("mmap");
    }
    /*
       fprintf(stdout, "buffer length %d\n", vdev->buf_len[i]);
       */
  }

  return 0;
}

int v4l2_open(const char *device) {
  /* open video device with system call */
  /* TODO: why O_NONBLOCK here? */
  int video_fd = open(device, O_RDWR | O_NONBLOCK);
  if (video_fd == -1) {
    return v4l2_error("Could not open video device");
  } else {
    return video_fd;
  }
}

int v4l2_close_query(v4l2_device *vdev) {
  release_node(vdev->ctrl_map);
  vdev->ctrl_map = NULL;
  release_node(vdev->menu_map);
  vdev->menu_map = NULL;
  return 0;
}

int v4l2_close(v4l2_device *vdev) {
  /* uninit mmap */
  v4l2_uninit_mmap(vdev);
  /* TODO: free control */
  v4l2_close_query(vdev);
  if (vdev->fd == -1) {
    return 0;
  } else if (close(vdev->fd) == -1) {
    return v4l2_error("Closing video device");
  }
  vdev->fd = -1;
  return 0;
}

int v4l2_init(v4l2_device *vdev) {
  struct v4l2_capability video_cap;
  /* check if capture and streaming device */
  if (xioctl(vdev->fd, VIDIOC_QUERYCAP, &video_cap) == -1) {
    return v4l2_error("VIDIOC_QUERYCAP");
  }
  if (!(video_cap.capabilities & V4L2_CAP_VIDEO_CAPTURE)) {
    return v4l2_error("No video capture device");
  }
  if (!(video_cap.capabilities & V4L2_CAP_STREAMING)) {
    return v4l2_error("No capture streaming");
  }

  /* Get current format */
  struct v4l2_format video_fmt;
  video_fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(vdev->fd, VIDIOC_G_FMT, &video_fmt) == -1) {
    return v4l2_error("VIDIOC_G_FMT: Fail Get Format");
  }

  /* Set video format, such as width, height, pixelformat */
  video_fmt.fmt.pix.width = vdev->width;
  video_fmt.fmt.pix.height = vdev->height;
  video_fmt.fmt.pix.field = V4L2_FIELD_NONE;
  if (strcmp(vdev->pixelformat, "yuyv") == 0) {
    video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
  } else if (strcmp(vdev->pixelformat, "mjpeg") == 0) {
    video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
  } else if (strcmp(vdev->pixelformat, "uyvy") == 0) {
    video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_UYVY; /* iSight */
  } else {
    return v4l2_error("VIDIOC_S_FMT: Unknown pixel format");
  }
  if (xioctl(vdev->fd, VIDIOC_S_FMT, &video_fmt) == -1) {
    return v4l2_error("VIDIOC_S_FMT: Fail Set Resolution and Pixel Format");
  }

  /*
     fprintf(stdout, "Current Format\n");
     fprintf(stdout, "+------------+\n");
     fprintf(stdout, "width: %u\n", video_fmt.fmt.pix.width);
     fprintf(stdout, "height: %u\n", video_fmt.fmt.pix.height);
     fprintf(stdout, "pixel format: %u\n", video_fmt.fmt.pix.pixelformat);
     fprintf(stdout, "pixel field: %u\n", video_fmt.fmt.pix.field);
     fflush(stdout);
     fprintf(stdout, "start querying\n");
     */
  /* base control */
  v4l2_query_ctrl(vdev, V4L2_CID_BASE, V4L2_CID_LASTP1 + 100);
  /* camera class control */
  v4l2_query_ctrl(vdev, V4L2_CID_CAMERA_CLASS_BASE, V4L2_CID_PRIVACY + 100);
  /* driver specfic control */
  v4l2_query_ctrl(vdev, V4L2_CID_PRIVATE_BASE, V4L2_CID_PRIVATE_BASE + 100);

  /* set desired frame rate */
  /*
     fprintf(stdout, "setting frame rate...\n");
     fflush(stdout);
     */
  struct v4l2_streamparm streamparm;
  streamparm.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(vdev->fd, VIDIOC_G_PARM, &streamparm) == -1) {
    return v4l2_error("failed to get stream parameters");
  }

  /* Nao driver requires set default frame rate to (1/0) not (1/30) */
  streamparm.parm.capture.timeperframe.numerator = vdev->fps_num;
  streamparm.parm.capture.timeperframe.denominator = vdev->fps_denum;
  if (xioctl(vdev->fd, VIDIOC_S_PARM, &streamparm) == -1) {
    return v4l2_error("failed to set frame rate");
  }
  /*
     fprintf(stdout, "frame rate: %d/%d\n",
     streamparm.parm.capture.timeperframe.numerator,
     streamparm.parm.capture.timeperframe.denominator);
     fflush(stdout);
     */

  /* Initialize memory map */
  v4l2_init_mmap(vdev);

  return 0;
}

int v4l2_stream_on(v4l2_device *vdev) {
  int i = 0;
  struct v4l2_buffer buf;
  for (i = 0; i < NBUFFERS; i++) {
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = i;
    if (xioctl(vdev->fd, VIDIOC_QBUF, &buf) == -1) {
      return v4l2_error("VIDIOC_QBUF");
    }
  }

  enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  /*
     printf("fd %d stream on\n", vdev->fd);
     */
  if (xioctl(vdev->fd, VIDIOC_STREAMON, &type) == -1) {
    return v4l2_error("VIDIOC_STREAMON");
  }
  return 0;
}

int v4l2_stream_off(v4l2_device *vdev) {
  enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(vdev->fd, VIDIOC_STREAMOFF, &type) == -1) {
    return v4l2_error("VIDIOC_STREAMOFF");
  }
  return 0;
}

int v4l2_get_ctrl(v4l2_device *vdev, const char *name, int *value) {
  struct v4l2_queryctrl *ictrl =
      (struct v4l2_queryctrl *)get_query_node(vdev->ctrl_map, name);
  if (ictrl == NULL) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }

  struct v4l2_control ctrl;
  ctrl.id = ictrl->id;
  int ret = xioctl(vdev->fd, VIDIOC_G_CTRL, &ctrl);
  *value = ctrl.value;
  return ret;
}

int v4l2_set_ctrl(v4l2_device *vdev, const char *name, int value) {
  struct v4l2_queryctrl *ictrl =
      (struct v4l2_queryctrl *)get_query_node(vdev->ctrl_map, name);
  if (ictrl == NULL) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }
  int v4l2_cid_base = 0x00980900;
  /*
     fprintf(stderr, "Setting ctrl %s, id %d\n", name,ictrl->id-v4l2_cid_base);
     */
  struct v4l2_control ctrl;
  ctrl.id = ictrl->id;
  ctrl.value = value;
  int ret = xioctl(vdev->fd, VIDIOC_S_CTRL, &ctrl);
  return ret;
}

int v4l2_read_frame(v4l2_device *vdev) {
  struct v4l2_buffer buf;
  buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  buf.memory = V4L2_MEMORY_MMAP;
  if (xioctl(vdev->fd, VIDIOC_DQBUF, &buf) == -1) {
    switch (errno) {
    case EAGAIN:
      /* fprintf(stdout, "no frame available\n"); */
      return -1;
    case EIO:
    /* Could ignore EIO */
    default:
      return v4l2_error("VIDIOC_DQBUF");
    }
  } else if (buf.index >= NBUFFERS) {
    fprintf(stderr, "Index out of bounds %d / %d\n", buf.index, NBUFFERS);
    return v4l2_error("VIDIOC_QBUF");
  } else if (xioctl(vdev->fd, VIDIOC_QBUF, &buf) == -1) {
    fprintf(stderr, "QBUF erro %d | Buffer: Index %d Type %d\n", errno,
            buf.index, buf.type);
    return v4l2_error("VIDIOC_QBUF");
  }
  int index = buf.index;
  // In case of MJPEG data
  vdev->buf_used[index] = buf.bytesused;
  return index;
}
