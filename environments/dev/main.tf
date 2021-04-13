# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  env = "dev"
}

provider "google" {
  project = "${var.project}"
}

module "vpc" {
  source  = "../../modules/vpc"
  project = "${var.project}"
  env     = "${local.env}"
}

module "http_server" {
  source  = "../../modules/http_server"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}

module "firewall" {
  source  = "../../modules/firewall"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}
  
module "bigquery" {
  source                     = "terraform-google-modules/bigquery/google"
  version                    = "~> 4.4"
  #project                    = "${var.project}"
  dataset_id                 = "dwh_us"
  dataset_name               = "dw"
  description                = "Our main data warehouse located in the US"
  project_id                 = "${var.project}"
  location                   = "US"
  delete_contents_on_destroy = true
  tables = [
    {
      table_id           = "wikipedia_pageviews_2021",
      schema             = "schemas/pageviews_2021.schema.json",
      time_partitioning {
        type  = "DAY"
        field = "datehour"
        require_partition_filter = true
      },
      expiration_time    = 2524604400000, # 2050/01/01
      clustering = [ "wiki", "title" ],
      labels = {
        env      = "dev"
        billable = "true"
        #owner    = "joedoe"
      },
    }
  ]
  dataset_labels = {
    env      = "dev"
    billable = "true"
    #owner    = "janesmith"
  }
}
