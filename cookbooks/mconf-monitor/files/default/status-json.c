/**************************************************************************
 *
 * STATUS-JSON.C -  Nagios Status CGI
 *
 * Copyright (c) 1999-2010  Ethan Galstad (egalstad@nagios.org)
 * Last Modified: 03-29-2011
 * MM: Modified version of status CGI to provide JSON
 *
 * License:
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *************************************************************************/

#include "../include/config.h"
#include "../include/common.h"
#include "../include/objects.h"
#include "../include/comments.h"
#include "../include/macros.h"
#include "../include/statusdata.h"

#include "../include/cgiutils.h"
#include "../include/getcgi.h"
#include "../include/cgiauth.h"

extern int             refresh_rate;
extern time_t          program_start;

extern char main_config_file[MAX_FILENAME_LENGTH];
extern char url_html_path[MAX_FILENAME_LENGTH];
extern char url_docs_path[MAX_FILENAME_LENGTH];
extern char url_images_path[MAX_FILENAME_LENGTH];
extern char url_stylesheets_path[MAX_FILENAME_LENGTH];
extern char url_logo_images_path[MAX_FILENAME_LENGTH];
extern char url_media_path[MAX_FILENAME_LENGTH];
extern char log_file[MAX_FILENAME_LENGTH];


extern char *notes_url_target;
extern char *action_url_target;

extern int suppress_alert_window;

extern host *host_list;
extern service *service_list;
extern hostgroup *hostgroup_list;
extern servicegroup *servicegroup_list;
extern hoststatus *hoststatus_list;
extern servicestatus *servicestatus_list;


#define MAX_MESSAGE_BUFFER		4096

#define DISPLAY_HOSTS			0
#define DISPLAY_HOSTGROUPS		1
#define DISPLAY_SERVICEGROUPS           2

#define STYLE_OVERVIEW			0
#define STYLE_DETAIL			1
#define STYLE_SUMMARY			2
#define STYLE_GRID                      3
#define STYLE_HOST_DETAIL               4
#define STYLE_MCONF_GRID	5

/* HOSTSORT structure */
typedef struct hostsort_struct{
	hoststatus *hststatus;
	struct hostsort_struct *next;
        }hostsort;

/* SERVICESORT structure */
typedef struct servicesort_struct{
	servicestatus *svcstatus;
	struct servicesort_struct *next;
        }servicesort;

hostsort *hostsort_list=NULL;
servicesort *servicesort_list=NULL;

int sort_services(int,int);						/* sorts services */
int sort_hosts(int,int);                                                /* sorts hosts */
int compare_servicesort_entries(int,int,servicesort *,servicesort *);	/* compares service sort entries */
int compare_hostsort_entries(int,int,hostsort *,hostsort *);            /* compares host sort entries */
void free_servicesort_list(void);
void free_hostsort_list(void);

void show_host_status_totals(void);
void show_service_status_totals(void);
void show_service_detail(void);
void show_host_detail(void);
void show_servicegroup_overviews(void);
void show_servicegroup_overview(servicegroup *);
void show_servicegroup_summaries(void);
void show_servicegroup_summary(servicegroup *);
void show_servicegroup_host_totals_summary(servicegroup *);
void show_servicegroup_service_totals_summary(servicegroup *);
void show_servicegroup_grids(void);
void show_servicegroup_grid(servicegroup *);
void show_hostgroup_overviews(void);
void show_hostgroup_overview(hostgroup *);
void show_servicegroup_hostgroup_member_overview(hoststatus *,void *);
void show_servicegroup_hostgroup_member_service_status_totals(char *,void *);
void show_hostgroup_summaries(void);
void show_hostgroup_summary(hostgroup *,int);
void show_hostgroup_host_totals_summary(hostgroup *);
void show_hostgroup_service_totals_summary(hostgroup *);
void show_hostgroup_grids(void);
void show_hostgroup_grid(hostgroup *);
void show_mconf_hostgroup_grids(void);
void show_mconf_hostgroup_grid(hostgroup *);

int passes_host_properties_filter(hoststatus *);
int passes_service_properties_filter(servicestatus *);

void document_header(int);
void document_footer(void);
int process_cgivars(void);


authdata current_authdata;
time_t current_time;

char alert_message[MAX_MESSAGE_BUFFER];
char *host_name=NULL;
char *host_filter=NULL;
char *hostgroup_name=NULL;
char *servicegroup_name=NULL;
char *service_filter=NULL;
int host_alert=FALSE;
int show_all_hosts=TRUE;
int show_all_hostgroups=TRUE;
int show_all_servicegroups=TRUE;
int display_type=DISPLAY_HOSTS;
int overview_columns=3;
int max_grid_width=8;
int group_style_type=STYLE_OVERVIEW;

int service_status_types=SERVICE_PENDING|SERVICE_OK|SERVICE_UNKNOWN|SERVICE_WARNING|SERVICE_CRITICAL;
int all_service_status_types=SERVICE_PENDING|SERVICE_OK|SERVICE_UNKNOWN|SERVICE_WARNING|SERVICE_CRITICAL;

int host_status_types=HOST_PENDING|HOST_UP|HOST_DOWN|HOST_UNREACHABLE;
int all_host_status_types=HOST_PENDING|HOST_UP|HOST_DOWN|HOST_UNREACHABLE;

int all_service_problems=SERVICE_UNKNOWN|SERVICE_WARNING|SERVICE_CRITICAL;
int all_host_problems=HOST_DOWN|HOST_UNREACHABLE;

unsigned long host_properties=0L;
unsigned long service_properties=0L;

int sort_type=SORT_NONE;
int sort_option=SORT_HOSTNAME;

int problem_hosts_down=0;
int problem_hosts_unreachable=0;
int problem_services_critical=0;
int problem_services_warning=0;
int problem_services_unknown=0;

int embedded=FALSE;



int main(void){
	int result=OK;
	host *temp_host=NULL;
	hostgroup *temp_hostgroup=NULL;
	servicegroup *temp_servicegroup=NULL;
	int regex_i=1,i=0;
	int len;
	
	time(&current_time);

	/* get the arguments passed in the URL */
	process_cgivars();

	/* reset internal variables */
	reset_cgi_vars();

	/* read the CGI configuration file */
	result=read_cgi_config_file(get_cgi_config_location());
	if(result==ERROR){
		document_header(FALSE);
		cgi_config_file_error(get_cgi_config_location());
		document_footer();
		return ERROR;
	}

	/* read the main configuration file */
	result=read_main_config_file(main_config_file);
	if(result==ERROR){
		document_header(FALSE);
		main_config_file_error(main_config_file);
		document_footer();
		return ERROR;
	}

	/* read all object configuration data */
	result=read_all_object_configuration_data(main_config_file,READ_ALL_OBJECT_DATA);
	if(result==ERROR){
		document_header(FALSE);
		object_data_error();
		document_footer();
		return ERROR;
    }

	/* read all status data */
	result=read_all_status_data(get_cgi_config_location(),READ_ALL_STATUS_DATA);
	if(result==ERROR){
		document_header(FALSE);
		status_data_error();
		document_footer();
		free_memory();
		return ERROR;
    }

	/* initialize macros */
	init_macros();

	document_header(TRUE);

	/* get authentication information */
	get_authentication_information(&current_authdata);

	/*
	show_host_status_totals();
	show_service_status_totals();
	*/
	
	/* bottom portion of screen - service or hostgroup detail */
	if(display_type==DISPLAY_HOSTS)
		show_service_detail();
	else if(display_type==DISPLAY_SERVICEGROUPS){
		if(group_style_type==STYLE_OVERVIEW)
			show_servicegroup_overviews();
		else if(group_style_type==STYLE_SUMMARY)
			show_servicegroup_summaries();
		else if(group_style_type==STYLE_GRID)
			show_servicegroup_grids();
		else if(group_style_type==STYLE_HOST_DETAIL)
			show_host_detail();
		else
			show_service_detail();
	}
	else{
		if(group_style_type==STYLE_OVERVIEW)
			show_hostgroup_overviews();
		else if(group_style_type==STYLE_SUMMARY)
			show_hostgroup_summaries();
		else if(group_style_type==STYLE_GRID)
			show_hostgroup_grids();
		else if(group_style_type==STYLE_HOST_DETAIL)
			show_host_detail();
		else if(group_style_type==STYLE_MCONF_GRID)
			show_mconf_hostgroup_grids();
		else
			show_service_detail();
	}

	document_footer();

	/* free all allocated memory */
	free_memory();
	free_comment_data();

	/* free memory allocated to the sort lists */
	free_servicesort_list();
	free_hostsort_list();

	return OK;
}


void document_header(int use_stylesheet){
	char date_time[MAX_DATETIME_LENGTH];
	time_t expire_time;

	printf("Cache-Control: no-store\r\n");
	printf("Pragma: no-cache\r\n");
	printf("Refresh: %d\r\n",refresh_rate);

	get_time_string(&current_time,date_time,(int)sizeof(date_time),HTTP_DATE_TIME);
	printf("Last-Modified: %s\r\n",date_time);

	expire_time=(time_t)0L;
	get_time_string(&expire_time,date_time,(int)sizeof(date_time),HTTP_DATE_TIME);
	printf("Expires: %s\r\n",date_time);

	printf("Content-type: application/json\r\n\r\n");

	if(embedded==TRUE)
		return;

	/* include user SSI header */
/*	include_ssi_files(STATUS_CGI,SSI_HEADER); */

	return;
}


void document_footer(void){

	if(embedded==TRUE)
		return;

	/* include user SSI footer */
/*	include_ssi_files(STATUS_CGI,SSI_FOOTER);*/

	return;
}


int process_cgivars(void){
	char **variables;
	int error=FALSE;
	int x;

	variables=getcgivars();

	for(x=0;variables[x]!=NULL;x++){

		/* do some basic length checking on the variable identifier to prevent buffer overflows */
		if(strlen(variables[x])>=MAX_INPUT_BUFFER-1){
			x++;
			continue;
		}

		
		/* we found the hostgroup argument */
		else if(!strcmp(variables[x],"hostgroup")){
			display_type=DISPLAY_HOSTGROUPS;
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			hostgroup_name=(char *)strdup(variables[x]);
			strip_html_brackets(hostgroup_name);

			if(hostgroup_name!=NULL && !strcmp(hostgroup_name,"all"))
				show_all_hostgroups=TRUE;
			else
				show_all_hostgroups=FALSE;
		        }

		/* we found the servicegroup argument */
		else if(!strcmp(variables[x],"servicegroup")){
			display_type=DISPLAY_SERVICEGROUPS;
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			}

			servicegroup_name=strdup(variables[x]);
			strip_html_brackets(servicegroup_name);

			if(servicegroup_name!=NULL && !strcmp(servicegroup_name,"all"))
				show_all_servicegroups=TRUE;
			else
				show_all_servicegroups=FALSE;
		}

		/* we found the host argument */
		else if(!strcmp(variables[x],"host")){
			display_type=DISPLAY_HOSTS;
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			}

			host_name=strdup(variables[x]);
			strip_html_brackets(host_name);

			if(host_name!=NULL && !strcmp(host_name,"all"))
				show_all_hosts=TRUE;
			else
				show_all_hosts=FALSE;
			}

		/* we found the columns argument */
		else if(!strcmp(variables[x],"columns")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			overview_columns=atoi(variables[x]);
			if(overview_columns<=0)
				overview_columns=1;
		        }

		/* we found the service status type argument */
		else if(!strcmp(variables[x],"servicestatustypes")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			service_status_types=atoi(variables[x]);
		        }

		/* we found the host status type argument */
		else if(!strcmp(variables[x],"hoststatustypes")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			host_status_types=atoi(variables[x]);
		        }

		/* we found the service properties argument */
		else if(!strcmp(variables[x],"serviceprops")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			service_properties=strtoul(variables[x],NULL,10);
		        }

		/* we found the host properties argument */
		else if(!strcmp(variables[x],"hostprops")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			host_properties=strtoul(variables[x],NULL,10);
		        }

		/* we found the host or service group style argument */
		else if(!strcmp(variables[x],"style")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			if(!strcmp(variables[x],"overview"))
				group_style_type=STYLE_OVERVIEW;
			else if(!strcmp(variables[x],"detail"))
				group_style_type=STYLE_DETAIL;
			else if(!strcmp(variables[x],"summary"))
				group_style_type=STYLE_SUMMARY;
			else if(!strcmp(variables[x],"grid"))
				group_style_type=STYLE_GRID;
			else if(!strcmp(variables[x],"hostdetail"))
				group_style_type=STYLE_HOST_DETAIL;
			else if(!strcmp(variables[x],"mconf"))
				group_style_type=STYLE_MCONF_GRID;
			else
				group_style_type=STYLE_DETAIL;
		        }

		/* we found the sort type argument */
		else if(!strcmp(variables[x],"sorttype")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			sort_type=atoi(variables[x]);
		        }

		/* we found the sort option argument */
		else if(!strcmp(variables[x],"sortoption")){
			x++;
			if(variables[x]==NULL){
				error=TRUE;
				break;
			        }

			sort_option=atoi(variables[x]);
		        }

		/* we found the embed option */
		else if(!strcmp(variables[x],"embedded"))
			embedded=TRUE;

		
		/* servicefilter cgi var */
                else if(!strcmp(variables[x],"servicefilter")){
                        x++;
                        if(variables[x]==NULL){
                                error=TRUE;
                                break;
                                }
                        service_filter=strdup(variables[x]);
			strip_html_brackets(service_filter);
                        }
	        }

	/* free memory allocated to the CGI variables */
	free_cgivars(variables);

	return error;
}



/* display table with service status totals... */
void show_service_status_totals(void){
	int total_ok=0;
	int total_warning=0;
	int total_unknown=0;
	int total_critical=0;
	int total_pending=0;
	int total_services=0;
	int total_problems=0;
	servicestatus *temp_servicestatus;
	service *temp_service;
	host *temp_host;
	int count_service;


	/* check the status of all services... */
	for(temp_servicestatus=servicestatus_list;temp_servicestatus!=NULL;temp_servicestatus=temp_servicestatus->next){

		/* find the host and service... */
		temp_host=find_host(temp_servicestatus->host_name);
		temp_service=find_service(temp_servicestatus->host_name,temp_servicestatus->description);

		/* make sure user has rights to see this service... */
		if(is_authorized_for_service(temp_service,&current_authdata)==FALSE)
			continue;

		count_service=0;

		if(display_type==DISPLAY_HOSTS && (show_all_hosts==TRUE || !strcmp(host_name,temp_servicestatus->host_name)))
			count_service=1;
		else if(display_type==DISPLAY_SERVICEGROUPS && (show_all_servicegroups==TRUE || (is_service_member_of_servicegroup(find_servicegroup(servicegroup_name),temp_service)==TRUE)))
			count_service=1;
		else if(display_type==DISPLAY_HOSTGROUPS && (show_all_hostgroups==TRUE || (is_host_member_of_hostgroup(find_hostgroup(hostgroup_name),temp_host)==TRUE)))
			count_service=1;

		if(count_service){

			if(temp_servicestatus->status==SERVICE_CRITICAL){
				total_critical++;
				if(temp_servicestatus->problem_has_been_acknowledged==FALSE && (temp_servicestatus->checks_enabled==TRUE || temp_servicestatus->accept_passive_service_checks==TRUE) && temp_servicestatus->notifications_enabled==TRUE && temp_servicestatus->scheduled_downtime_depth==0)
					problem_services_critical++;
			        }
			else if(temp_servicestatus->status==SERVICE_WARNING){
				total_warning++;
				if(temp_servicestatus->problem_has_been_acknowledged==FALSE && (temp_servicestatus->checks_enabled==TRUE || temp_servicestatus->accept_passive_service_checks==TRUE) && temp_servicestatus->notifications_enabled==TRUE && temp_servicestatus->scheduled_downtime_depth==0)
					problem_services_warning++;
			        }
			else if(temp_servicestatus->status==SERVICE_UNKNOWN){
				total_unknown++;
				if(temp_servicestatus->problem_has_been_acknowledged==FALSE && (temp_servicestatus->checks_enabled==TRUE || temp_servicestatus->accept_passive_service_checks==TRUE) && temp_servicestatus->notifications_enabled==TRUE && temp_servicestatus->scheduled_downtime_depth==0)
					problem_services_unknown++;
			        }
			else if(temp_servicestatus->status==SERVICE_OK)
				total_ok++;
			else if(temp_servicestatus->status==SERVICE_PENDING)
				total_pending++;
			else
				total_ok++;
		        }
	        }

	total_services=total_ok+total_unknown+total_warning+total_critical+total_pending;
	total_problems=total_unknown+total_warning+total_critical;

printf("{\n");
printf("\t \"service_status_totals\":\n");
printf("\t {\n");

printf("\t\t \"total_ok\":%d,\n",total_ok);
printf("\t\t \"total_unknown\":%d,\n",total_unknown);
printf("\t\t \"total_warning\":%d,\n",total_warning);
printf("\t\t \"total_critical\":%d,\n",total_critical);
printf("\t\t \"total_pending\":%d,\n",total_pending);
printf("\t\t \"total_services\":%d,\n",total_services);
printf("\t\t \"total_problems\":%d\n",total_problems);

printf("\t }\n");
printf("}\n");

	return;
}


/* display a table with host status totals... */
void show_host_status_totals(void){
	int total_up=0;
	int total_down=0;
	int total_unreachable=0;
	int total_pending=0;
	int total_hosts=0;
	int total_problems=0;
	int total_ok=0;
	int total_critical=0;
	int total_unknown=0;
	hoststatus *temp_hoststatus;
	host *temp_host;
	servicestatus *temp_servicestatus;
	int count_host;


	/* check the status of all hosts... */
	for(temp_hoststatus=hoststatus_list;temp_hoststatus!=NULL;temp_hoststatus=temp_hoststatus->next){

		/* find the host... */
		temp_host=find_host(temp_hoststatus->host_name);

		/* make sure user has rights to view this host */
		if(is_authorized_for_host(temp_host,&current_authdata)==FALSE)
			continue;

		count_host=0;

		if(display_type==DISPLAY_HOSTS && (show_all_hosts==TRUE || !strcmp(host_name,temp_hoststatus->host_name)))
			count_host=1;
		else if(display_type==DISPLAY_SERVICEGROUPS){
			if(show_all_servicegroups==TRUE){
				count_host=1;
				}
			else{

				for(temp_servicestatus=servicestatus_list;temp_servicestatus!=NULL;temp_servicestatus=temp_servicestatus->next){
					if(is_host_member_of_servicegroup(find_servicegroup(servicegroup_name),temp_host)==TRUE){
						count_host=1;
						break;
					}
				}

			}
		}
		else if(display_type==DISPLAY_HOSTGROUPS && (show_all_hostgroups==TRUE || (is_host_member_of_hostgroup(find_hostgroup(hostgroup_name),temp_host)==TRUE)))
			count_host=1;

		if(count_host){

			if(temp_hoststatus->status==HOST_UP)
				total_up++;
			else if(temp_hoststatus->status==HOST_DOWN){
				total_down++;
				if(temp_hoststatus->problem_has_been_acknowledged==FALSE && temp_hoststatus->notifications_enabled==TRUE && temp_hoststatus->checks_enabled==TRUE && temp_hoststatus->scheduled_downtime_depth==0)
					problem_hosts_down++;
			        }
			else if(temp_hoststatus->status==HOST_UNREACHABLE){
				total_unreachable++;
				if(temp_hoststatus->problem_has_been_acknowledged==FALSE && temp_hoststatus->notifications_enabled==TRUE && temp_hoststatus->checks_enabled==TRUE && temp_hoststatus->scheduled_downtime_depth==0)
					problem_hosts_unreachable++;
			        }

			else if(temp_hoststatus->status==HOST_PENDING)
				total_pending++;
			else
				total_up++;
		}
	}

	total_hosts=total_up+total_down+total_unreachable+total_pending;
	total_problems=total_down+total_unreachable;

printf("{\n");
printf("\t \"host_status_totals\":\n");
printf("\t {\n");

printf("\t\t \"total_ok\":%d,\n",total_ok);
printf("\t\t \"total_unknown\":%d,\n",total_unknown);
printf("\t\t \"total_unreachable\":%d,\n",total_unreachable);
printf("\t\t \"total_critical\":%d,\n",total_critical);
printf("\t\t \"total_pending\":%d,\n",total_pending);
printf("\t\t \"total_hosts\":%d,\n",total_hosts);
printf("\t\t \"total_problems\":%d\n",total_problems);

printf("\t }\n");
printf("}\n");

	return;
}



/* display a detailed listing of the status of all services... */
void show_service_detail(void){
	regex_t preg, preg_hostname;
	time_t t;
	char date_time[MAX_DATETIME_LENGTH];
	char state_duration[48];
	char status[MAX_INPUT_BUFFER];
	char temp_buffer[MAX_INPUT_BUFFER];
	char temp_url[MAX_INPUT_BUFFER];
	char *processed_string=NULL;
	char *status_class="";
	char *status_bg_class="";
	char *host_status_bg_class="";
	char *last_host="";
	int new_host=FALSE;
	servicestatus *temp_status=NULL;
	hostgroup *temp_hostgroup=NULL;
	servicegroup *temp_servicegroup=NULL;
	hoststatus *temp_hoststatus=NULL;
	host *temp_host=NULL;
	service *temp_service=NULL;
	int odd=0;
	int total_comments=0;
	int user_has_seen_something=FALSE;
	servicesort *temp_servicesort=NULL;
	int use_sort=FALSE;
	int result=OK;
	int first_entry=TRUE;
	int days;
	int hours;
	int minutes;
	int seconds;
	int duration_error=FALSE;
	int total_entries=0;
	int show_service=FALSE;

	char *service_last_check="";
	char *service_status="";
	int host_status=0;
	char *host_address="";
	int host_problem_has_been_acknowledged=FALSE;
	int host_has_comments=0;
	int host_notifications_enabled=TRUE;
	int host_checks_enabled=TRUE;
	int host_is_flapping=FALSE;
	int host_scheduled_downtime_depth=0;
	char *host_notes_url="";
	char *host_action_url="";
	char *host_icon_image="";
	char *service_description="";
	int service_has_comments=0;
	int service_problem_has_been_acknowledged=FALSE;
	int service_checks_enabled=TRUE;
	int service_accept_passive_service_checks=TRUE;
	int service_notifications_enabled=TRUE;
	int service_is_flapping=FALSE;
	int service_scheduled_downtime_depth=0;
	char *service_notes_url="";
	char *service_action_url="";
	char *service_icon_image="";
	char *service_state_duration="";
	int service_current_attempt=0;
	int service_max_attempts=0;
	char *service_plugin_output="";

	/* sort the service list if necessary */
	if(sort_type!=SORT_NONE){
		result=sort_services(sort_type,sort_option);
		if(result==ERROR)
			use_sort=FALSE;
		else
			use_sort=TRUE;
	}
	else
		use_sort=FALSE;

	snprintf(temp_url,sizeof(temp_url)-1,"%s?",STATUS_CGI);
	temp_url[sizeof(temp_url)-1]='\x0';
	if(display_type==DISPLAY_HOSTS)
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"host=%s",url_encode(host_name));
	else if(display_type==DISPLAY_SERVICEGROUPS)
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"servicegroup=%s&style=detail",url_encode(servicegroup_name));
	else
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"hostgroup=%s&style=detail",url_encode(hostgroup_name));
	temp_buffer[sizeof(temp_buffer)-1]='\x0';
	strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
	temp_url[sizeof(temp_url)-1]='\x0';

	if(service_status_types!=all_service_status_types){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&servicestatustypes=%d",service_status_types);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	}
	if(host_status_types!=all_host_status_types){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&hoststatustypes=%d",host_status_types);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	}
	if(service_properties!=0){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&serviceprops=%lu",service_properties);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	}
	if(host_properties!=0){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&hostprops=%lu",host_properties);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	}

	/* the main list of services */

	if(service_filter!=NULL)
		regcomp(&preg,service_filter,0);
	if(host_filter!=NULL)
		regcomp(&preg_hostname,host_filter,REG_ICASE);

	temp_hostgroup=find_hostgroup(hostgroup_name);
	temp_servicegroup=find_servicegroup(servicegroup_name);

printf("{\n");
printf("\t\"services\":\n");
printf("\t[\n");
	/* check all services... */
	while(1){

	    service_problem_has_been_acknowledged=FALSE;
	    service_checks_enabled=TRUE;
	    service_accept_passive_service_checks=TRUE;
	    service_notifications_enabled=TRUE;
	    service_is_flapping=FALSE;

		/* get the next service to display */
		if(use_sort==TRUE){
			if(first_entry==TRUE)
				temp_servicesort=servicesort_list;
			else
				temp_servicesort=temp_servicesort->next;
			if(temp_servicesort==NULL)
				break;
			temp_status=temp_servicesort->svcstatus;
		}
		else{
			if(first_entry==TRUE)
				temp_status=servicestatus_list;
			else
				temp_status=temp_status->next;
		}

		if(temp_status==NULL)
			break;

		first_entry=FALSE;

		/* find the service  */
		temp_service=find_service(temp_status->host_name,temp_status->description);

		/* if we couldn't find the service, go to the next service */
		if(temp_service==NULL)
			continue;

		/* find the host */
		temp_host=find_host(temp_service->host_name);

		/* make sure user has rights to see this... */
		if(is_authorized_for_service(temp_service,&current_authdata)==FALSE)
			continue;

		user_has_seen_something=TRUE;

		/* get the host status information */
		temp_hoststatus=find_hoststatus(temp_service->host_name);

		/* see if we should display services for hosts with tis type of status */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* see if we should display this type of service status */
		if(!(service_status_types & temp_status->status))
			continue;	

		/* check host properties filter */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		/* check service properties filter */
		if(passes_service_properties_filter(temp_status)==FALSE)
			continue;

		/* servicefilter cgi var */
                if(service_filter!=NULL)
			if(regexec(&preg,temp_status->description,0,NULL,0))
				continue;

		show_service=FALSE;

		if(display_type==DISPLAY_HOSTS){
			if(show_all_hosts==TRUE)
				show_service=TRUE;
			else if(host_filter!=NULL && 0==regexec(&preg_hostname,temp_status->host_name,0,NULL,0))
				show_service=TRUE;
			else if(!strcmp(host_name,temp_status->host_name))
				show_service=TRUE;
		}

		else if(display_type==DISPLAY_HOSTGROUPS){
			if(show_all_hostgroups==TRUE)
				show_service=TRUE;
			else if(is_host_member_of_hostgroup(temp_hostgroup,temp_host)==TRUE)
				show_service=TRUE;
		}

		else if(display_type==DISPLAY_SERVICEGROUPS){
			if(show_all_servicegroups==TRUE)
				show_service=TRUE;
			else if(is_service_member_of_servicegroup(temp_servicegroup,temp_service)==TRUE)
				show_service=TRUE;
		}

		if(show_service==TRUE){

			if(strcmp(last_host,temp_status->host_name))
				new_host=TRUE;
			else
				new_host=FALSE;

			/* keep track of total number of services we're displaying */
			total_entries++;

	        /* get the last service check time */
			t=temp_status->last_check;
			get_time_string(&t,date_time,(int)sizeof(date_time),SHORT_DATE_TIME);
			if((unsigned long)temp_status->last_check==0L)
				strcpy(date_time,"N/A");

			service_last_check=date_time;
			
			/* create status string */
			if(temp_status->status==SERVICE_PENDING){
				strncpy(status,"PENDING",sizeof(status));
			}
			else if(temp_status->status==SERVICE_OK){
				strncpy(status,"OK",sizeof(status));
			}
			else if(temp_status->status==SERVICE_WARNING){
				strncpy(status,"WARNING",sizeof(status));
			}
			else if(temp_status->status==SERVICE_UNKNOWN){
				strncpy(status,"UNKNOWN",sizeof(status));
			}
			else if(temp_status->status==SERVICE_CRITICAL){
				strncpy(status,"CRITICAL",sizeof(status));
			}
			status[sizeof(status)-1]='\x0';
			service_status=status;

printf("\t\t{\n");
printf("\t\t\t \"service_status\":\"%s\",\n",service_status);
printf("\t\t\t \"service_host\":\n");
printf("\t\t\t\t{ \n");
				/* grab macros */
				grab_host_macros(temp_host);

				host_status=temp_hoststatus->status;

				host_address=temp_host->address;
				host_name=temp_status->host_name;

				total_comments=number_of_host_comments(temp_host->name);
				if(temp_hoststatus->problem_has_been_acknowledged==TRUE){
					host_problem_has_been_acknowledged=TRUE;
                }
				/* only show comments if this is a non-read-only user */
				if(is_authorized_for_read_only(&current_authdata)==FALSE){
					if(total_comments>0)
						host_has_comments=total_comments;
				}
				if(temp_hoststatus->notifications_enabled==FALSE){
					host_notifications_enabled=FALSE;
                }
				if(temp_hoststatus->checks_enabled==FALSE){
					host_checks_enabled=FALSE;
		        }
				if(temp_hoststatus->is_flapping==TRUE){
					host_is_flapping=TRUE;
		        }
				if(temp_hoststatus->scheduled_downtime_depth>0){
					host_scheduled_downtime_depth=temp_hoststatus->scheduled_downtime_depth;
		        }
				if(temp_host->notes_url!=NULL){
					process_macros(temp_host->notes_url,&processed_string,0);
					host_notes_url=processed_string;
		        }
				if(temp_host->action_url!=NULL){
					process_macros(temp_host->action_url,&processed_string,0);
					host_action_url=processed_string;
		        }
				if(temp_host->icon_image!=NULL){
					process_macros(temp_host->icon_image,&processed_string,0);
					host_icon_image=processed_string;
		        }

printf("\t\t\t\t \"host_status\":%d, \n", host_status);
printf("\t\t\t\t \"host_address\":\"%s\", \n", host_address);
printf("\t\t\t\t \"host_name\":\"%s\", \n", host_name);
printf("\t\t\t\t \"host_problem_has_been_acknowledged\":%d, \n", host_problem_has_been_acknowledged);
printf("\t\t\t\t \"host_has_comments\":%d, \n", host_has_comments);
printf("\t\t\t\t \"host_notifications_enabled\":%d, \n", host_notifications_enabled);
printf("\t\t\t\t \"host_checks_enabled\":%d, \n", host_checks_enabled);
printf("\t\t\t\t \"host_is_flapping\":%d, \n", host_is_flapping);
printf("\t\t\t\t \"host_scheduled_downtime_depth\":%d, \n", host_scheduled_downtime_depth);
printf("\t\t\t\t \"host_notes_url\":\"%s\", \n", host_notes_url);
printf("\t\t\t\t \"host_action_url\":\"%s\", \n", host_action_url);
printf("\t\t\t\t \"host_icon_image\":\"%s\" \n", host_icon_image);
printf("\t\t\t\t }, \n");

			/* grab macros */
			grab_service_macros(temp_service);

			/* service name column */
			service_description=temp_status->description;

			total_comments=number_of_service_comments(temp_service->host_name,temp_service->description);
			/* only show comments if this is a non-read-only user */
			if(is_authorized_for_read_only(&current_authdata)==FALSE){
				if(total_comments>0){
					service_has_comments=total_comments;
				}
			}
			if(temp_status->problem_has_been_acknowledged==TRUE){
				service_problem_has_been_acknowledged=TRUE;
	        }
			if(temp_status->checks_enabled==FALSE && temp_status->accept_passive_service_checks==FALSE){
				service_checks_enabled=FALSE;
			}
			if(temp_status->accept_passive_service_checks==FALSE){
				service_accept_passive_service_checks=FALSE;
			}
			if(temp_status->notifications_enabled==FALSE){
				service_notifications_enabled=FALSE;
	        }
			if(temp_status->is_flapping==TRUE){
				service_is_flapping=TRUE;
			}
			if(temp_status->scheduled_downtime_depth>0){
				service_scheduled_downtime_depth=temp_status->scheduled_downtime_depth;
	        }
			if(temp_service->notes_url!=NULL){
				process_macros(temp_service->notes_url,&processed_string,0);
				service_notes_url=processed_string;
			}
			if(temp_service->action_url!=NULL){
				process_macros(temp_service->action_url,&processed_string,0);
				service_action_url=processed_string;
			}
			if(temp_service->icon_image!=NULL){
				process_macros(temp_service->icon_image,&processed_string,0);
				service_icon_image=processed_string;
	        }

			/* state duration calculation... */
			t=0;
			duration_error=FALSE;
			if(temp_status->last_state_change==(time_t)0){
				if(program_start>current_time)
					duration_error=TRUE;
				else
					t=current_time-program_start;
			        }
			else{
				if(temp_status->last_state_change>current_time)
					duration_error=TRUE;
				else
					t=current_time-temp_status->last_state_change;
			        }
			get_time_breakdown((unsigned long)t,&days,&hours,&minutes,&seconds);
			if(duration_error==TRUE)
				snprintf(state_duration,sizeof(state_duration)-1,"???");
			else
				snprintf(state_duration,sizeof(state_duration)-1,"%2dd %2dh %2dm %2ds%s",days,hours,minutes,seconds,(temp_status->last_state_change==(time_t)0)?"+":"");
			state_duration[sizeof(state_duration)-1]='\x0';
			service_state_duration=state_duration;

			service_current_attempt=temp_status->current_attempt;
			service_max_attempts=temp_status->max_attempts;

			service_plugin_output=(temp_status->plugin_output==NULL)?"":html_encode(temp_status->plugin_output,TRUE);

			last_host=temp_status->host_name;

printf("\t\t\t \"service_description\":\"%s\", \n", service_description);
printf("\t\t\t \"service_problem_has_been_acknowledged\":%d, \n", service_problem_has_been_acknowledged);
printf("\t\t\t \"service_has_comments\":%d, \n", service_has_comments);
printf("\t\t\t \"service_accept_passive_service_checks\":%d, \n", service_accept_passive_service_checks);
printf("\t\t\t \"service_notifications_enabled\":%d, \n", service_notifications_enabled);
printf("\t\t\t \"service_checks_enabled\":%d, \n", service_checks_enabled);
printf("\t\t\t \"service_is_flapping\":%d, \n", service_is_flapping);
printf("\t\t\t \"service_scheduled_downtime_depth\":%d, \n", service_scheduled_downtime_depth);
printf("\t\t\t \"service_notes_url\":\"%s\", \n", service_notes_url);
printf("\t\t\t \"service_action_url\":\"%s\", \n", service_action_url);
printf("\t\t\t \"service_icon_image\":\"%s\", \n", service_icon_image);
printf("\t\t\t \"service_state_duration\":\"%s\", \n", service_state_duration);
printf("\t\t\t \"service_current_attempt\":%d, \n", service_current_attempt);
printf("\t\t\t \"service_max_attempts\":%d, \n", service_max_attempts);
printf("\t\t\t \"service_plugin_output\":\"%s\" \n", service_plugin_output);

printf("\t\t},\n");
	        }
	}

printf("\t\t{}\n");

printf("\t]\n");
printf("}\n");

	return;
}



/* display a detailed listing of the status of all hosts... */
void show_host_detail(void){
	time_t t;
	char date_time[MAX_DATETIME_LENGTH];
	char state_duration[48];
	char status[MAX_INPUT_BUFFER];
	char temp_buffer[MAX_INPUT_BUFFER];
	char temp_url[MAX_INPUT_BUFFER];
	char *processed_string=NULL;
	char *status_class="";
	char *status_bg_class="";
	hoststatus *temp_status=NULL;
	hostgroup *temp_hostgroup=NULL;
	host *temp_host=NULL;
	hostsort *temp_hostsort=NULL;
	int odd=0;
	int total_comments=0;
	int user_has_seen_something=FALSE;
	int use_sort=FALSE;
	int result=OK;
	int first_entry=TRUE;
	int days;
	int hours;
	int minutes;
	int seconds;
	int duration_error=FALSE;
	int total_entries=0;

	char *host_status="";
	char *host_address="";
	int host_problem_has_been_acknowledged=FALSE;
	int host_has_comments=0;
	int host_notifications_enabled=TRUE;
	int host_checks_enabled=TRUE;
	int host_is_flapping=FALSE;
	int host_scheduled_downtime_depth=0;
	char *host_notes_url="";
	char *host_action_url="";
	char *host_icon_image="";
	char *host_state_duration="";
	char *host_last_check="";
	char *host_plugin_output="";

	/* sort the host list if necessary */
	if(sort_type!=SORT_NONE){
		result=sort_hosts(sort_type,sort_option);
		if(result==ERROR)
			use_sort=FALSE;
		else
			use_sort=TRUE;
	        }
	else
		use_sort=FALSE;


	snprintf(temp_url,sizeof(temp_url)-1,"%s?",STATUS_CGI);
	temp_url[sizeof(temp_url)-1]='\x0';
	snprintf(temp_buffer,sizeof(temp_buffer)-1,"hostgroup=%s&style=hostdetail",url_encode(hostgroup_name));
	temp_buffer[sizeof(temp_buffer)-1]='\x0';
	strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
	temp_url[sizeof(temp_url)-1]='\x0';
	if(service_status_types!=all_service_status_types){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&servicestatustypes=%d",service_status_types);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	        }
	if(host_status_types!=all_host_status_types){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&hoststatustypes=%d",host_status_types);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	        }
	if(service_properties!=0){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&serviceprops=%lu",service_properties);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	        }
	if(host_properties!=0){
		snprintf(temp_buffer,sizeof(temp_buffer)-1,"&hostprops=%lu",host_properties);
		temp_buffer[sizeof(temp_buffer)-1]='\x0';
		strncat(temp_url,temp_buffer,sizeof(temp_url)-strlen(temp_url)-1);
		temp_url[sizeof(temp_url)-1]='\x0';
	        }

printf("{\"hosts\":\n");
printf("\t[\n");

	/* the main list of hosts */
	/* check all hosts... */
	while(1){

		/* get the next service to display */
		if(use_sort==TRUE){
			if(first_entry==TRUE)
				temp_hostsort=hostsort_list;
			else
				temp_hostsort=temp_hostsort->next;
			if(temp_hostsort==NULL)
				break;
			temp_status=temp_hostsort->hststatus;
	                }
		else{
			if(first_entry==TRUE)
				temp_status=hoststatus_list;
			else
				temp_status=temp_status->next;
		        }

		if(temp_status==NULL)
			break;

		first_entry=FALSE;

		/* find the host  */
		temp_host=find_host(temp_status->host_name);

		/* if we couldn't find the host, go to the next status entry */
		if(temp_host==NULL)
			continue;

		/* make sure user has rights to see this... */
		if(is_authorized_for_host(temp_host,&current_authdata)==FALSE)
			continue;

		user_has_seen_something=TRUE;

		/* see if we should display services for hosts with this type of status */
		if(!(host_status_types & temp_status->status))
			continue;

		/* check host properties filter */
		if(passes_host_properties_filter(temp_status)==FALSE)
			continue;


		/* see if this host is a member of the hostgroup */
		if(show_all_hostgroups==FALSE){
			temp_hostgroup=find_hostgroup(hostgroup_name);
			if(temp_hostgroup==NULL)
				continue;
			if(is_host_member_of_hostgroup(temp_hostgroup,temp_host)==FALSE)
				continue;
	                }
	
		total_entries++;

		/* grab macros */
		grab_host_macros(temp_host);


		if(display_type==DISPLAY_HOSTGROUPS){

printf("\t\t{\n");

	        /* get the last host check time */
			t=temp_status->last_check;
			get_time_string(&t,date_time,(int)sizeof(date_time),SHORT_DATE_TIME);
			if((unsigned long)temp_status->last_check==0L)
				strcpy(date_time,"N/A");
			host_last_check=date_time;

			if(temp_status->status==HOST_PENDING){
				strncpy(status,"PENDING",sizeof(status));
                }
			else if(temp_status->status==HOST_UP){
				strncpy(status,"UP",sizeof(status));
                }
			else if(temp_status->status==HOST_DOWN){
				strncpy(status,"DOWN",sizeof(status));
                }
			else if(temp_status->status==HOST_UNREACHABLE){
				strncpy(status,"UNREACHABLE",sizeof(status));
                }
			status[sizeof(status)-1]='\x0';
			host_status=status;

			/**** host name column ****/

			host_name=temp_status->host_name;
			host_address=temp_host->address;

			total_comments=number_of_host_comments(temp_host->name);
			if(temp_status->problem_has_been_acknowledged==TRUE){
				host_problem_has_been_acknowledged=TRUE;
			}
			if(total_comments>0){
				host_has_comments=total_comments;
			}
			if(temp_status->notifications_enabled==FALSE){
				host_notifications_enabled=FALSE;
			}
			if(temp_status->checks_enabled==FALSE){
				host_checks_enabled=FALSE;
	        }
			if(temp_status->is_flapping==TRUE){
				host_is_flapping=TRUE;
	        }
			if(temp_status->scheduled_downtime_depth>0){
				host_scheduled_downtime_depth=temp_status->scheduled_downtime_depth;
	        }
			if(temp_host->notes_url!=NULL){
				process_macros(temp_host->notes_url,&processed_string,0);
				host_notes_url=processed_string;
		        }
			if(temp_host->action_url!=NULL){
				process_macros(temp_host->action_url,&processed_string,0);
				host_action_url=processed_string;
	        }
			if(temp_host->icon_image!=NULL){
				process_macros(temp_host->icon_image,&processed_string,0);
				host_icon_image=processed_string;
			}

			/* state duration calculation... */
			t=0;
			duration_error=FALSE;
			if(temp_status->last_state_change==(time_t)0){
				if(program_start>current_time)
					duration_error=TRUE;
				else
					t=current_time-program_start;
			        }
			else{
				if(temp_status->last_state_change>current_time)
					duration_error=TRUE;
				else
					t=current_time-temp_status->last_state_change;
			        }
			get_time_breakdown((unsigned long)t,&days,&hours,&minutes,&seconds);
			if(duration_error==TRUE)
				snprintf(state_duration,sizeof(state_duration)-1,"???");
			else
				snprintf(state_duration,sizeof(state_duration)-1,"%2dd %2dh %2dm %2ds%s",days,hours,minutes,seconds,(temp_status->last_state_change==(time_t)0)?"+":"");
			state_duration[sizeof(state_duration)-1]='\x0';
			host_state_duration=state_duration;

			host_plugin_output=(temp_status->plugin_output==NULL)?"":html_encode(temp_status->plugin_output,TRUE);

printf("\t\t\t \"host_status\":\"%s\", \n", host_status);
printf("\t\t\t \"host_address\":\"%s\", \n", host_address);
printf("\t\t\t \"host_name\":\"%s\", \n", host_name);
printf("\t\t\t \"host_problem_has_been_acknowledged\":%d, \n", host_problem_has_been_acknowledged);
printf("\t\t\t \"host_has_comments\":%d, \n", host_has_comments);
printf("\t\t\t \"host_notifications_enabled\":%d, \n", host_notifications_enabled);
printf("\t\t\t \"host_checks_enabled\":%d, \n", host_checks_enabled);
printf("\t\t\t \"host_is_flapping\":%d, \n", host_is_flapping);
printf("\t\t\t \"host_scheduled_downtime_depth\":%d, \n", host_scheduled_downtime_depth);
printf("\t\t\t \"host_notes_url\":\"%s\", \n", host_notes_url);
printf("\t\t\t \"host_action_url\":\"%s\", \n", host_action_url);
printf("\t\t\t \"host_icon_image\":\"%s\" \n", host_icon_image);
printf("\t\t}, \n");

		}

	}
printf("\t\t{}\n");

printf("\t]\n");
printf("}\n");

	return;
}




/* show an overview of servicegroup(s)... */
void show_servicegroup_overviews(void){
	servicegroup *temp_servicegroup=NULL;
	int current_column;
	int user_has_seen_something=FALSE;
	int servicegroup_error=FALSE;

printf("{\"servicegroups\":[\n");
	
	/* display status overviews for all servicegroups */
	if(show_all_servicegroups==TRUE){

		/* loop through all servicegroups... */
		for(temp_servicegroup=servicegroup_list;temp_servicegroup!=NULL;temp_servicegroup=temp_servicegroup->next){

			/* make sure the user is authorized to view at least one host in this servicegroup */
			if(is_authorized_for_servicegroup(temp_servicegroup,&current_authdata)==FALSE)
				continue;

			show_servicegroup_overview(temp_servicegroup);

			user_has_seen_something=TRUE;
		}
	}
	/* else display overview for just a specific servicegroup */
	else{

		temp_servicegroup=find_servicegroup(servicegroup_name);
		if(temp_servicegroup!=NULL){

			if(is_authorized_for_servicegroup(temp_servicegroup,&current_authdata)==TRUE){

				show_servicegroup_overview(temp_servicegroup);
				
				user_has_seen_something=TRUE;
	        }

        }
	}

printf("\t{}\n");

printf("]\n");
printf("}\n");

	return;
}



/* shows an overview of a specific servicegroup... */
void show_servicegroup_overview(servicegroup *temp_servicegroup){
	servicesmember *temp_member;
	host *temp_host;
	host *last_host;
	hoststatus *temp_hoststatus=NULL;

	char *servicegroup_name="";
	char *servicegroup_alias="";

	servicegroup_name=temp_servicegroup->group_name;
	servicegroup_alias=temp_servicegroup->alias;
	
	/* find all hosts that have services that are members of the servicegroup */
	last_host=NULL;
	for(temp_member=temp_servicegroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* skip this if it isn't a new host... */
		if(temp_host==last_host)
			continue;

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		show_servicegroup_hostgroup_member_overview(temp_hoststatus,temp_servicegroup);

		last_host=temp_host;
	}

	return;
}



/* show a summary of servicegroup(s)... */
void show_servicegroup_summaries(void){
	servicegroup *temp_servicegroup=NULL;
	int user_has_seen_something=FALSE;
	int servicegroup_error=FALSE;

printf("{\"servicegroups\":\n");
printf("\t[\n");

	/* display status summary for all servicegroups */
	if(show_all_servicegroups==TRUE){

		/* loop through all servicegroups... */
		for(temp_servicegroup=servicegroup_list;temp_servicegroup!=NULL;temp_servicegroup=temp_servicegroup->next){

			/* make sure the user is authorized to view at least one host in this servicegroup */
			if(is_authorized_for_servicegroup(temp_servicegroup,&current_authdata)==FALSE)
				continue;

			/* show summary for this servicegroup */
			show_servicegroup_summary(temp_servicegroup);

			user_has_seen_something=TRUE;
		}
	}

	/* else just show summary for a specific servicegroup */
	else{
		temp_servicegroup=find_servicegroup(servicegroup_name);
		if(temp_servicegroup==NULL)
			servicegroup_error=TRUE;
		else{
			show_servicegroup_summary(temp_servicegroup);
			user_has_seen_something=TRUE;
        }
	}

printf("\t{}\n");
printf("\t]\n");
printf("}\n");

	return;
}



/* displays status summary information for a specific servicegroup */
void show_servicegroup_summary(servicegroup *temp_servicegroup){
	char *status_bg_class="";

	char *servicegroup_name="";
	char *servicegroup_alias="";

	servicegroup_name=temp_servicegroup->group_name;
	servicegroup_alias=temp_servicegroup->alias;

printf("\t{\n");
printf("\t\t \"servicegroup_name\":\"%s\",\n",temp_servicegroup->group_name);
printf("\t\t \"servicegroup_alias\":\"%s\",\n",temp_servicegroup->alias);
printf("\t\t \"servicegroup_host_totals\":\n");

	show_servicegroup_host_totals_summary(temp_servicegroup);

printf("\t\t,\n");
printf("\t\t \"servicegroup_service_totals\":\n");

	show_servicegroup_service_totals_summary(temp_servicegroup);

printf("\t},\n");


	return;
}



/* shows host total summary information for a specific servicegroup */
void show_servicegroup_host_totals_summary(servicegroup *temp_servicegroup){
	servicesmember *temp_member;
	int hosts_up=0;
	int hosts_down=0;
	int hosts_unreachable=0;
	int hosts_pending=0;
	int hosts_down_scheduled=0;
	int hosts_down_acknowledged=0;
	int hosts_down_disabled=0;
	int hosts_down_unacknowledged=0;
	int hosts_unreachable_scheduled=0;
	int hosts_unreachable_acknowledged=0;
	int hosts_unreachable_disabled=0;
	int hosts_unreachable_unacknowledged=0;
	hoststatus *temp_hoststatus=NULL;
	host *temp_host=NULL;
	host *last_host=NULL;
	int problem=FALSE;

	/* find all the hosts that belong to the servicegroup */
	for(temp_member=temp_servicegroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host... */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* skip this if it isn't a new host... */
		if(temp_host==last_host)
			continue;

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		problem=TRUE;

		if(temp_hoststatus->status==HOST_UP)
			hosts_up++;

		else if(temp_hoststatus->status==HOST_DOWN){
			if(temp_hoststatus->scheduled_downtime_depth>0){
				hosts_down_scheduled++;
				problem=FALSE;
			        }
			if(temp_hoststatus->problem_has_been_acknowledged==TRUE){
				hosts_down_acknowledged++;
				problem=FALSE;
			        }
			if(temp_hoststatus->checks_enabled==FALSE){
				hosts_down_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				hosts_down_unacknowledged++;
			hosts_down++;
		        }

		else if(temp_hoststatus->status==HOST_UNREACHABLE){
			if(temp_hoststatus->scheduled_downtime_depth>0){
				hosts_unreachable_scheduled++;
				problem=FALSE;
			        }
			if(temp_hoststatus->problem_has_been_acknowledged==TRUE){
				hosts_unreachable_acknowledged++;
				problem=FALSE;
			        }
			if(temp_hoststatus->checks_enabled==FALSE){
				hosts_unreachable_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				hosts_unreachable_unacknowledged++;
			hosts_unreachable++;
		        }

		else
			hosts_pending++;

		last_host=temp_host;
	}

/*
printf("{\n");
printf("\t\"servicegroup_name\":\"%s\",\n",temp_servicegroup->group_name);
printf("\t\"servicegroup_alias\":\"%s\",\n",temp_servicegroup->alias);
printf("\t\"summary\":\n");
*/
printf("\t\t{\n");
printf("\t\t\t\"hosts_up\":%d,\n",hosts_up);
printf("\t\t\t\"hosts_down\":%d,\n",hosts_down);
printf("\t\t\t\"hosts_unreachable\":%d,\n",hosts_unreachable);
printf("\t\t\t\"hosts_pending\":%d,\n",hosts_pending);
printf("\t\t\t\"hosts_down_scheduled\":%d,\n",hosts_down_scheduled);
printf("\t\t\t\"hosts_down_acknowledged\":%d,\n",hosts_down_acknowledged);
printf("\t\t\t\"hosts_down_disabled\":%d,\n",hosts_down_disabled);
printf("\t\t\t\"hosts_down_unacknowledged\":%d,\n",hosts_down_unacknowledged);
printf("\t\t\t\"hosts_unreachable_scheduled\":%d,\n",hosts_unreachable_scheduled);
printf("\t\t\t\"hosts_unreachable_acknowledged\":%d,\n",hosts_unreachable_acknowledged);
printf("\t\t\t\"hosts_unreachable_disabled\":%d,\n",hosts_unreachable_disabled);
printf("\t\t\t\"hosts_unreachable_unacknowledged\":%d\n",hosts_unreachable_unacknowledged);
printf("\t\t}\n");
/*
printf("}\n");
*/
	return;
}



/* shows service total summary information for a specific servicegroup */
void show_servicegroup_service_totals_summary(servicegroup *temp_servicegroup){
	int services_ok=0;
	int services_warning=0;
	int services_unknown=0;
	int services_critical=0;
	int services_pending=0;
	int services_warning_host_problem=0;
	int services_warning_scheduled=0;
	int services_warning_acknowledged=0;
	int services_warning_disabled=0;
	int services_warning_unacknowledged=0;
	int services_unknown_host_problem=0;
	int services_unknown_scheduled=0;
	int services_unknown_acknowledged=0;
	int services_unknown_disabled=0;
	int services_unknown_unacknowledged=0;
	int services_critical_host_problem=0;
	int services_critical_scheduled=0;
	int services_critical_acknowledged=0;
	int services_critical_disabled=0;
	int services_critical_unacknowledged=0;
	servicesmember *temp_member=NULL;
	servicestatus *temp_servicestatus=NULL;
	hoststatus *temp_hoststatus=NULL;
	service *temp_service=NULL;
	int problem=FALSE;


	/* find all the services that belong to the servicegroup */
	for(temp_member=temp_servicegroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the service */
		temp_service=find_service(temp_member->host_name,temp_member->service_description);
		if(temp_service==NULL)
			continue;

		/* find the service status */
		temp_servicestatus=find_servicestatus(temp_service->host_name,temp_service->description);
		if(temp_servicestatus==NULL)
			continue;

		/* find the status of the associated host */
		temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		/* make sure we only display services of the specified status levels */
		if(!(service_status_types & temp_servicestatus->status))
			continue;

		/* make sure we only display services that have the desired properties */
		if(passes_service_properties_filter(temp_servicestatus)==FALSE)
			continue;

		problem=TRUE;

		if(temp_servicestatus->status==SERVICE_OK)
			services_ok++;

		else if(temp_servicestatus->status==SERVICE_WARNING){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_warning_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_warning_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_warning_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_warning_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_warning_unacknowledged++;
			services_warning++;
		        }

		else if(temp_servicestatus->status==SERVICE_UNKNOWN){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_unknown_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_unknown_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_unknown_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_unknown_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_unknown_unacknowledged++;
			services_unknown++;
		        }

		else if(temp_servicestatus->status==SERVICE_CRITICAL){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_critical_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_critical_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_critical_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_critical_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_critical_unacknowledged++;
			services_critical++;
		        }

		else if(temp_servicestatus->status==SERVICE_PENDING)
			services_pending++;
	}

/*
printf("{\n");
printf("\t\"servicegroup_name\":\"%s\",",temp_servicegroup->group_name);
printf("\t\"servicegroup_alias\":\"%s\",",temp_servicegroup->alias);
printf("\t\"summary\":\n");
*/
printf("\t\t{\n");
printf("\t\t\t\"services_ok\":%d,\n",services_ok);
printf("\t\t\t\"services_warning\":%d,\n",services_warning);
printf("\t\t\t\"services_unknown\":%d,\n",services_unknown);
printf("\t\t\t\"services_critical\":%d,\n",services_critical);
printf("\t\t\t\"services_pending\":%d,\n",services_pending);
printf("\t\t\t\"services_warning_host_problem\":%d,\n",services_warning_host_problem);
printf("\t\t\t\"services_warning_scheduled\":%d,\n",services_warning_scheduled);
printf("\t\t\t\"services_warning_acknowledged\":%d,\n",services_warning_acknowledged);
printf("\t\t\t\"services_warning_disabled\":%d,\n",services_warning_disabled);
printf("\t\t\t\"services_warning_unacknowledged\":%d,\n",services_warning_unacknowledged);
printf("\t\t\t\"services_unknown_host_problem\":%d,\n",services_unknown_host_problem);
printf("\t\t\t\"services_unknown_scheduled\":%d,\n",services_unknown_scheduled);
printf("\t\t\t\"services_unknown_acknowledged\":%d,\n",services_unknown_acknowledged);
printf("\t\t\t\"services_unknown_disabled\":%d,\n",services_unknown_disabled);
printf("\t\t\t\"services_unknown_unacknowledged\":%d,\n",services_unknown_unacknowledged);
printf("\t\t\t\"services_critical_host_problem\":%d,\n",services_critical_host_problem);
printf("\t\t\t\"services_critical_scheduled\":%d,\n",services_critical_scheduled);
printf("\t\t\t\"services_critical_acknowledged\":%d,\n",services_critical_acknowledged);
printf("\t\t\t\"services_critical_disabled\":%d,\n",services_critical_disabled);
printf("\t\t\t\"services_critical_unacknowledged\":%d\n",services_critical_unacknowledged);
printf("\t\t}\n");
/*
printf("}\n");
*/

	return;
}



/* show a grid layout of servicegroup(s)... */
void show_servicegroup_grids(void){
	servicegroup *temp_servicegroup=NULL;
	int user_has_seen_something=FALSE;
	int servicegroup_error=FALSE;

printf("{\"servicegroups\":\n");
printf("\t[\n");

	/* display status grids for all servicegroups */
	if(show_all_servicegroups==TRUE){

		/* loop through all servicegroups... */
		for(temp_servicegroup=servicegroup_list;temp_servicegroup!=NULL;temp_servicegroup=temp_servicegroup->next){

			/* make sure the user is authorized to view at least one host in this servicegroup */
			if(is_authorized_for_servicegroup(temp_servicegroup,&current_authdata)==FALSE)
				continue;

			/* show grid for this servicegroup */
			show_servicegroup_grid(temp_servicegroup);

			user_has_seen_something=TRUE;
        }

	}

	/* else just show grid for a specific servicegroup */
	else{
		temp_servicegroup=find_servicegroup(servicegroup_name);
		if(temp_servicegroup==NULL)
			servicegroup_error=TRUE;
		else{
			show_servicegroup_grid(temp_servicegroup);
			user_has_seen_something=TRUE;
	    }
	}

printf("\t{}\n");

printf("\t]\n");
printf("}\n");
	return;
}


/* displays status grid for a specific servicegroup */
void show_servicegroup_grid(servicegroup *temp_servicegroup){
	char *status_bg_class="";
	char *host_status_class="";
	char *service_status_class="";
	char *processed_string=NULL;
	servicesmember *temp_member;
	servicesmember *temp_member2;
	host *temp_host;
	host *last_host;
	hoststatus *temp_hoststatus;
	servicestatus *temp_servicestatus;
	int current_item;

	char *servicegroup_name="";
	char *servicegroup_alias="";
	char *host_icon_image="";
	int service_status=0;
	char *service_description="";
	char *service_host_name="";
	char *host_notes_url="";
	char *host_action_url="";
	
	servicegroup_name=temp_servicegroup->group_name;
	servicegroup_alias=temp_servicegroup->alias;

printf("\t{\n");
printf("\t\"servicegroup_name\":\"%s\",\n",servicegroup_name);
printf("\t\"servicegroup_alias\":\"%s\",\n",servicegroup_alias);
printf("\t\"hosts\":\n");
printf("\t\t [\n");

	/* find all hosts that have services that are members of the servicegroup */
	last_host=NULL;
	for(temp_member=temp_servicegroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* get the status of the host */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		/* skip this if it isn't a new host... */
		if(temp_host==last_host)
			continue;

		host_name=temp_host->name;

		if(temp_host->icon_image!=NULL){
			process_macros(temp_host->icon_image,&processed_string,0);
			host_icon_image=processed_string;
        }

printf("\t\t\t{\n");
printf("\t\t\t\t\"host_name\":\"%s\",\n",host_name);
printf("\t\t\t\t\"host_icon_image\":\"%s\",\n",host_icon_image);
printf("\t\t\t\t\"services\":\n");
printf("\t\t\t\t[\n");

		/* display all services on the host that are part of the hostgroup */
		current_item=1;
		for(temp_member2=temp_member;temp_member2!=NULL;temp_member2=temp_member2->next){

			/* bail out if we've reached the end of the services that are associated with this servicegroup */
			if(strcmp(temp_member2->host_name,temp_host->name))
				break;

			/* get the status of the service */
			temp_servicestatus=find_servicestatus(temp_member2->host_name,temp_member2->service_description);
			service_status=(temp_servicestatus==NULL)?0:(temp_servicestatus->status);
			service_description=temp_servicestatus->description;
			service_host_name=temp_servicestatus->host_name;

			current_item++;

printf("\t\t\t\t\t{\n");
printf("\t\t\t\t\t\t\"service_status\":%d,\n",service_status);
printf("\t\t\t\t\t\t\"service_description\":\"%s\",\n",service_description);
printf("\t\t\t\t\t\t\"service_host_name\":\"%s\"\n",service_host_name);
printf("\t\t\t\t\t},\n");
		}
printf("\t\t\t\t\t{}\n");
printf("\t\t\t\t],\n");

		/* grab macros */
		grab_host_macros(temp_host);

		if(temp_host->notes_url!=NULL){
			process_macros(temp_host->notes_url,&processed_string,0);
			host_notes_url=processed_string;
        }
		if(temp_host->action_url!=NULL){
			process_macros(temp_host->action_url,&processed_string,0);
			host_action_url=processed_string;
        }

printf("\t\t\t\t\"host_notes_url\":\"%s\",\n",host_notes_url);
printf("\t\t\t\t\"host_action_url\":\"%s\"\n",host_action_url);
printf("\t\t\t},\n");

		last_host=temp_host;
	}
printf("\t\t\t{}\n");
printf("\t\t]\n");

printf("\t},\n");

	return;
}



/* show an overview of hostgroup(s)... */
void show_hostgroup_overviews(void){
	hostgroup *temp_hostgroup=NULL;
	int current_column;
	int user_has_seen_something=FALSE;
	int hostgroup_error=FALSE;

printf("{\"hostgroups\":[\n");

	/* display status overviews for all hostgroups */
	if(show_all_hostgroups==TRUE){


		/* loop through all hostgroups... */
		for(temp_hostgroup=hostgroup_list;temp_hostgroup!=NULL;temp_hostgroup=temp_hostgroup->next){

			/* make sure the user is authorized to view this hostgroup */
			if(is_authorized_for_hostgroup(temp_hostgroup,&current_authdata)==FALSE)
				continue;

			show_hostgroup_overview(temp_hostgroup);
			user_has_seen_something=TRUE;
        }
	}
	/* else display overview for just a specific hostgroup */
	else{
		temp_hostgroup=find_hostgroup(hostgroup_name);
		if(temp_hostgroup!=NULL){

			if(is_authorized_for_hostgroup(temp_hostgroup,&current_authdata)==TRUE){
				show_hostgroup_overview(temp_hostgroup);
				user_has_seen_something=TRUE;
	        }
        }
	}

printf("\t{}\n");

printf("]\n");
printf("}\n");

	return;
}



/* shows an overview of a specific hostgroup... */
void show_hostgroup_overview(hostgroup *hstgrp){
	hostsmember *temp_member=NULL;
	host *temp_host=NULL;
	hoststatus *temp_hoststatus=NULL;

	char *hostgroup_name="";
	char *hostgroup_alias="";

	/* make sure the user is authorized to view this hostgroup */
	if(is_authorized_for_hostgroup(hstgrp,&current_authdata)==FALSE)
		return;

	hostgroup_name=hstgrp->group_name;
	hostgroup_alias=hstgrp->alias;

printf("\t{\n");
printf("\t\t \"hostgroup_name\":\"%s\",\n",hostgroup_name);
printf("\t\t \"hostgroup_alias\":\"%s\",\n",hostgroup_alias);
printf("\t\t \"hosts\":\n");
printf("\t\t [\n");

	/* find all the hosts that belong to the hostgroup */
	for(temp_member=hstgrp->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host... */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		show_servicegroup_hostgroup_member_overview(temp_hoststatus,NULL);
	}
printf("\t\t\t{}\n");
printf("\t\t ]\n");
printf("\t},\n");

	return;
}

 

/* shows a host status overview... */
void show_servicegroup_hostgroup_member_overview(hoststatus *hststatus,void *data){
	char status[MAX_INPUT_BUFFER];
	char *status_bg_class="";
	char *status_class="";
	host *temp_host=NULL;
	char *processed_string=NULL;

	char *host_status=NULL;
	char *host_address=NULL;
	char *host_name=NULL;
	char *host_icon_image=NULL;
	char *host_action_url=NULL;
	char *host_notes_url=NULL;
	
	temp_host=find_host(hststatus->host_name);

	/* grab macros */
	grab_host_macros(temp_host);

	if(hststatus->status==HOST_PENDING){
		strncpy(status,"PENDING",sizeof(status));
	}
	else if(hststatus->status==HOST_UP){
		strncpy(status,"UP",sizeof(status));
	}
	else if(hststatus->status==HOST_DOWN){
		strncpy(status,"DOWN",sizeof(status));
	}
	else if(hststatus->status==HOST_UNREACHABLE){
		strncpy(status,"UNREACHABLE",sizeof(status));
	}

	status[sizeof(status)-1]='\x0';
	host_status=status;
	
	host_address=temp_host->address;
	host_name=temp_host->name;

printf("\t\t\t{\n");
printf("\t\t\t\t \"host_address\":\"%s\",\n",host_address);
printf("\t\t\t\t \"host_name\":\"%s\",\n",host_name);

	if(temp_host->icon_image!=NULL){
		process_macros(temp_host->icon_image,&processed_string,0);
		host_icon_image=processed_string;
	}

printf("\t\t\t\t \"member_status_totals\":\n");

	show_servicegroup_hostgroup_member_service_status_totals(hststatus->host_name,data);

printf("\t\t\t\t,\n");

	if(temp_host->notes_url!=NULL){
		process_macros(temp_host->notes_url,&processed_string,0);
		host_notes_url=processed_string;
	}
	if(temp_host->action_url!=NULL){
		process_macros(temp_host->action_url,&processed_string,0);
		host_action_url=processed_string;
	}

printf("\t\t\t\t \"host_notes_url\":\"%s\",\n",host_notes_url);
printf("\t\t\t\t \"host_action_url\":\"%s\"\n",host_action_url);

printf("\t\t\t},\n");
	
	return;
}



void show_servicegroup_hostgroup_member_service_status_totals(char *host_name,void *data){
	int total_ok=0;
	int total_warning=0;
	int total_unknown=0;
	int total_critical=0;
	int total_pending=0;
	servicestatus *temp_servicestatus;
	service *temp_service;
	servicegroup *temp_servicegroup=NULL;
	char temp_buffer[MAX_INPUT_BUFFER];

	int total_problems=0;
	int total_services=0;
	char *servicegroup_name=NULL;

	if(display_type==DISPLAY_SERVICEGROUPS)
		temp_servicegroup=(servicegroup *)data;

	/* check all services... */
	for(temp_servicestatus=servicestatus_list;temp_servicestatus!=NULL;temp_servicestatus=temp_servicestatus->next){

		if(!strcmp(host_name,temp_servicestatus->host_name)){

			/* make sure the user is authorized to see this service... */
			temp_service=find_service(temp_servicestatus->host_name,temp_servicestatus->description);
			if(is_authorized_for_service(temp_service,&current_authdata)==FALSE)
				continue;

			if(display_type==DISPLAY_SERVICEGROUPS){

				/* is this service a member of the servicegroup? */
				if(is_service_member_of_servicegroup(temp_servicegroup,temp_service)==FALSE)
					continue;
			        }

			/* make sure we only display services of the specified status levels */
			if(!(service_status_types & temp_servicestatus->status))
				continue;

			/* make sure we only display services that have the desired properties */
			if(passes_service_properties_filter(temp_servicestatus)==FALSE)
				continue;

			if(temp_servicestatus->status==SERVICE_CRITICAL)
				total_critical++;
			else if(temp_servicestatus->status==SERVICE_WARNING)
				total_warning++;
			else if(temp_servicestatus->status==SERVICE_UNKNOWN)
				total_unknown++;
			else if(temp_servicestatus->status==SERVICE_OK)
				total_ok++;
			else if(temp_servicestatus->status==SERVICE_PENDING)
				total_pending++;
			else
				total_ok++;
		}
	}

	total_services=total_ok+total_critical+total_warning+total_unknown+total_pending;
	total_problems=total_critical+total_warning;

	if(display_type==DISPLAY_SERVICEGROUPS)
		servicegroup_name=temp_servicegroup->group_name;
	temp_buffer[sizeof(temp_buffer)-1]='\x0';

printf("\t\t\t\t\t{\n");
printf("\t\t\t\t\t\t \"host_name\":\"%s\",\n",host_name);
printf("\t\t\t\t\t\t \"servicegroup_name\":\"%s\",\n",servicegroup_name);
printf("\t\t\t\t\t\t \"service_status_totals\":\n");
printf("\t\t\t\t\t\t {\n");
printf("\t\t\t\t\t\t\t \"total_ok\":%d,\n",total_ok);
printf("\t\t\t\t\t\t\t \"total_unknown\":%d,\n",total_unknown);
printf("\t\t\t\t\t\t\t \"total_warning\":%d,\n",total_warning);
printf("\t\t\t\t\t\t\t \"total_critical\":%d,\n",total_critical);
printf("\t\t\t\t\t\t\t \"total_pending\":%d,\n",total_pending);
printf("\t\t\t\t\t\t\t \"total_services\":%d,\n",total_services);
printf("\t\t\t\t\t\t\t \"total_problems\":%d\n",total_problems);
printf("\t\t\t\t\t\t }\n");
printf("\t\t\t\t\t}\n");

	return;
}



/* show a summary of hostgroup(s)... */
void show_hostgroup_summaries(void){
	hostgroup *temp_hostgroup=NULL;
	int user_has_seen_something=FALSE;
	int hostgroup_error=FALSE;
	int odd=0;

printf("{\"hostgroups\":\n");
printf("\t[\n");

	/* display status summary for all hostgroups */
	if(show_all_hostgroups==TRUE){

		/* loop through all hostgroups... */
		for(temp_hostgroup=hostgroup_list;temp_hostgroup!=NULL;temp_hostgroup=temp_hostgroup->next){

			/* make sure the user is authorized to view this hostgroup */
			if(is_authorized_for_hostgroup(temp_hostgroup,&current_authdata)==FALSE)
				continue;

			/* show summary for this hostgroup */
			show_hostgroup_summary(temp_hostgroup,odd);

			user_has_seen_something=TRUE;
		}
	}

	/* else just show summary for a specific hostgroup */
	else{
		temp_hostgroup=find_hostgroup(hostgroup_name);
		if(temp_hostgroup==NULL)
			hostgroup_error=TRUE;
		else{
			show_hostgroup_summary(temp_hostgroup,1);
			user_has_seen_something=TRUE;
		}
	}

printf("\t{}\n");
printf("\t]\n");
printf("}\n");

	return;
}



/* displays status summary information for a specific hostgroup */
void show_hostgroup_summary(hostgroup *temp_hostgroup,int odd){

printf("\t{\n");
printf("\t\t \"hostgroup_name\":\"%s\",\n",temp_hostgroup->group_name);
printf("\t\t \"hostgroup_alias\":\"%s\",\n",temp_hostgroup->alias);
printf("\t\t \"hostgroup_host_totals\":\n");
				
	show_hostgroup_host_totals_summary(temp_hostgroup);

printf("\t\t,\n");
printf("\t\t \"hostgroup_service_totals\":\n");

	show_hostgroup_service_totals_summary(temp_hostgroup);

printf("\t},\n");

	return;
}



/* shows host total summary information for a specific hostgroup */
void show_hostgroup_host_totals_summary(hostgroup *temp_hostgroup){
	hostsmember *temp_member;
	int hosts_up=0;
	int hosts_down=0;
	int hosts_unreachable=0;
	int hosts_pending=0;
	int hosts_down_scheduled=0;
	int hosts_down_acknowledged=0;
	int hosts_down_disabled=0;
	int hosts_down_unacknowledged=0;
	int hosts_unreachable_scheduled=0;
	int hosts_unreachable_acknowledged=0;
	int hosts_unreachable_disabled=0;
	int hosts_unreachable_unacknowledged=0;
	hoststatus *temp_hoststatus;
	host *temp_host;
	int problem=FALSE;

	/* find all the hosts that belong to the hostgroup */
	for(temp_member=temp_hostgroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host... */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		problem=TRUE;

		if(temp_hoststatus->status==HOST_UP)
			hosts_up++;

		else if(temp_hoststatus->status==HOST_DOWN){
			if(temp_hoststatus->scheduled_downtime_depth>0){
				hosts_down_scheduled++;
				problem=FALSE;
			        }
			if(temp_hoststatus->problem_has_been_acknowledged==TRUE){
				hosts_down_acknowledged++;
				problem=FALSE;
			        }
			if(temp_hoststatus->checks_enabled==FALSE){
				hosts_down_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				hosts_down_unacknowledged++;
			hosts_down++;
		        }

		else if(temp_hoststatus->status==HOST_UNREACHABLE){
			if(temp_hoststatus->scheduled_downtime_depth>0){
				hosts_unreachable_scheduled++;
				problem=FALSE;
			        }
			if(temp_hoststatus->problem_has_been_acknowledged==TRUE){
				hosts_unreachable_acknowledged++;
				problem=FALSE;
			        }
			if(temp_hoststatus->checks_enabled==FALSE){
				hosts_unreachable_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				hosts_unreachable_unacknowledged++;
			hosts_unreachable++;
		        }

		else
			hosts_pending++;
	        }

/*
printf("\t\t{\n");
printf("\t\t\t\"hostgroup_name\":\"%s\",\n",temp_hostgroup->group_name);
printf("\t\t\t\"hostgroup_alias\":\"%s\",\n",temp_hostgroup->alias);
printf("\t\t\t\"summary\":\n");
*/
printf("\t\t\t\t{\n");
printf("\t\t\t\t\t\"hosts_up\":%d,\n",hosts_up);
printf("\t\t\t\t\t\"hosts_down\":%d,\n",hosts_down);
printf("\t\t\t\t\t\"hosts_unreachable\":%d,\n",hosts_unreachable);
printf("\t\t\t\t\t\"hosts_pending\":%d,\n",hosts_pending);
printf("\t\t\t\t\t\"hosts_unreachable_scheduled\":%d,\n",hosts_unreachable_scheduled);
printf("\t\t\t\t\t\"hosts_unreachable_acknowledged\":%d,\n",hosts_unreachable_acknowledged);
printf("\t\t\t\t\t\"hosts_unreachable_disabled\":%d,\n",hosts_unreachable_disabled);
printf("\t\t\t\t\t\"hosts_unreachable_unacknowledged\":%d,\n",hosts_unreachable_unacknowledged);
printf("\t\t\t\t\t\"hosts_down_scheduled\":%d,\n",hosts_down_scheduled);
printf("\t\t\t\t\t\"hosts_down_acknowledged\":%d,\n",hosts_down_acknowledged);
printf("\t\t\t\t\t\"hosts_down_disabled\":%d,\n",hosts_down_disabled);
printf("\t\t\t\t\t\"hosts_down_unacknowledged\":%d\n",hosts_down_unacknowledged);
printf("\t\t\t\t}\n");
/*
printf("\t\t}\n");
*/
	return;
}



/* shows service total summary information for a specific hostgroup */
void show_hostgroup_service_totals_summary(hostgroup *temp_hostgroup){
	int services_ok=0;
	int services_warning=0;
	int services_unknown=0;
	int services_critical=0;
	int services_pending=0;
	int services_warning_host_problem=0;
	int services_warning_scheduled=0;
	int services_warning_acknowledged=0;
	int services_warning_disabled=0;
	int services_warning_unacknowledged=0;
	int services_unknown_host_problem=0;
	int services_unknown_scheduled=0;
	int services_unknown_acknowledged=0;
	int services_unknown_disabled=0;
	int services_unknown_unacknowledged=0;
	int services_critical_host_problem=0;
	int services_critical_scheduled=0;
	int services_critical_acknowledged=0;
	int services_critical_disabled=0;
	int services_critical_unacknowledged=0;
	servicestatus *temp_servicestatus=NULL;
	hoststatus *temp_hoststatus=NULL;
	host *temp_host=NULL;
	int problem=FALSE;


	/* check all services... */
	for(temp_servicestatus=servicestatus_list;temp_servicestatus!=NULL;temp_servicestatus=temp_servicestatus->next){

		/* find the host this service is associated with */
		temp_host=find_host(temp_servicestatus->host_name);
		if(temp_host==NULL)
			continue;

		/* see if this service is associated with a host in the specified hostgroup */
		if(is_host_member_of_hostgroup(temp_hostgroup,temp_host)==FALSE)
			continue;

		/* find the status of the associated host */
		temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
		if(temp_hoststatus==NULL)
			continue;

		/* find the status of the associated host */
		temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
		if(temp_hoststatus==NULL)
			continue;

		/* make sure we only display hosts of the specified status levels */
		if(!(host_status_types & temp_hoststatus->status))
			continue;

		/* make sure we only display hosts that have the desired properties */
		if(passes_host_properties_filter(temp_hoststatus)==FALSE)
			continue;

		/* make sure we only display services of the specified status levels */
		if(!(service_status_types & temp_servicestatus->status))
			continue;

		/* make sure we only display services that have the desired properties */
		if(passes_service_properties_filter(temp_servicestatus)==FALSE)
			continue;

		problem=TRUE;

		if(temp_servicestatus->status==SERVICE_OK)
			services_ok++;

		else if(temp_servicestatus->status==SERVICE_WARNING){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_warning_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_warning_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_warning_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_warning_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_warning_unacknowledged++;
			services_warning++;
		        }

		else if(temp_servicestatus->status==SERVICE_UNKNOWN){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_unknown_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_unknown_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_unknown_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_unknown_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_unknown_unacknowledged++;
			services_unknown++;
		        }

		else if(temp_servicestatus->status==SERVICE_CRITICAL){
			temp_hoststatus=find_hoststatus(temp_servicestatus->host_name);
			if(temp_hoststatus!=NULL && (temp_hoststatus->status==HOST_DOWN || temp_hoststatus->status==HOST_UNREACHABLE)){
				services_critical_host_problem++;
				problem=FALSE;
			        }
			if(temp_servicestatus->scheduled_downtime_depth>0){
				services_critical_scheduled++;
				problem=FALSE;
			        }
			if(temp_servicestatus->problem_has_been_acknowledged==TRUE){
				services_critical_acknowledged++;
				problem=FALSE;
			        }
			if(temp_servicestatus->checks_enabled==FALSE){
				services_critical_disabled++;
				problem=FALSE;
			        }
			if(problem==TRUE)
				services_critical_unacknowledged++;
			services_critical++;
		        }

		else if(temp_servicestatus->status==SERVICE_PENDING)
			services_pending++;
	        }

/*
printf("\t\t{\n");
printf("\t\t\t\"hostgroup_name\":\"%s\",\n",temp_hostgroup->group_name);
printf("\t\t\t\"hostgroup_alias\":\"%s\",\n",temp_hostgroup->alias);
printf("\t\t\t\"summary\":\n");
*/
printf("\t\t\t\t{\n");
printf("\t\t\t\t\t\"services_ok\":%d,\n",services_ok);
printf("\t\t\t\t\t\"services_warning\":%d,\n",services_warning);
printf("\t\t\t\t\t\"services_unknown\":%d,\n",services_unknown);
printf("\t\t\t\t\t\"services_critical\":%d,\n",services_critical);
printf("\t\t\t\t\t\"services_pending\":%d,\n",services_pending);
printf("\t\t\t\t\t\"services_warning_host_problem\":%d,\n",services_warning_host_problem);
printf("\t\t\t\t\t\"services_warning_scheduled\":%d,\n",services_warning_scheduled);
printf("\t\t\t\t\t\"services_warning_acknowledged\":%d,\n",services_warning_acknowledged);
printf("\t\t\t\t\t\"services_warning_disabled\":%d,\n",services_warning_disabled);
printf("\t\t\t\t\t\"services_warning_unacknowledged\":%d,\n",services_warning_unacknowledged);
printf("\t\t\t\t\t\"services_unknown_host_problem\":%d,\n",services_unknown_host_problem);
printf("\t\t\t\t\t\"services_unknown_scheduled\":%d,\n",services_unknown_scheduled);
printf("\t\t\t\t\t\"services_unknown_acknowledged\":%d,\n",services_unknown_acknowledged);
printf("\t\t\t\t\t\"services_unknown_disabled\":%d,\n",services_unknown_disabled);
printf("\t\t\t\t\t\"services_unknown_unacknowledged\":%d,\n",services_unknown_unacknowledged);
printf("\t\t\t\t\t\"services_critical_host_problem\":%d,\n",services_critical_host_problem);
printf("\t\t\t\t\t\"services_critical_scheduled\":%d,\n",services_critical_scheduled);
printf("\t\t\t\t\t\"services_critical_acknowledged\":%d,\n",services_critical_acknowledged);
printf("\t\t\t\t\t\"services_critical_disabled\":%d,\n",services_critical_disabled);
printf("\t\t\t\t\t\"services_critical_unacknowledged\":%d\n",services_critical_unacknowledged);
printf("\t\t\t\t}\n");
/*
printf("\t\t}\n");
*/
	return;
}



/* show a grid layout of hostgroup(s)... */
void show_hostgroup_grids(void){
	hostgroup *temp_hostgroup=NULL;
	int user_has_seen_something=FALSE;
	int hostgroup_error=FALSE;

printf("{\"hostgroups\":\n");
printf("\t[\n");

	/* display status grids for all hostgroups */
	if(show_all_hostgroups==TRUE){

		/* loop through all hostgroups... */
		for(temp_hostgroup=hostgroup_list;temp_hostgroup!=NULL;temp_hostgroup=temp_hostgroup->next){

			/* make sure the user is authorized to view this hostgroup */
			if(is_authorized_for_hostgroup(temp_hostgroup,&current_authdata)==FALSE)
				continue;

			/* show grid for this hostgroup */
			show_hostgroup_grid(temp_hostgroup);

			user_has_seen_something=TRUE;
		}
	}

	/* else just show grid for a specific hostgroup */
	else{
		temp_hostgroup=find_hostgroup(hostgroup_name);
		if(temp_hostgroup==NULL)
			hostgroup_error=TRUE;
		else{
			show_hostgroup_grid(temp_hostgroup);
			user_has_seen_something=TRUE;
		}
	}

printf("\t{}\n");

printf("\t]\n");
printf("}\n");
	return;
}


/* displays status grid for a specific hostgroup */
void show_hostgroup_grid(hostgroup *temp_hostgroup){
	hostsmember *temp_member;
	char *status_bg_class="";
	char *host_status_class="";
	char *service_status_class="";
	host *temp_host;
	service *temp_service;
	hoststatus *temp_hoststatus;
	servicestatus *temp_servicestatus;
	char *processed_string=NULL;
	int current_item;

	char *host_name="";
	char *host_icon_image="";
	int service_status=0;
	char *service_description="";
	char *service_host_name="";
	char *host_notes_url="";
	char *host_action_url="";
	

printf("\t{\n");
printf("\t\"hostgroup_name\":\"%s\",\n",temp_hostgroup->group_name);
printf("\t\"hostgroup_alias\":\"%s\",\n",temp_hostgroup->alias);
printf("\t\"hosts\":\n");
printf("\t\t [\n");

	/* find all the hosts that belong to the hostgroup */
	for(temp_member=temp_hostgroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host... */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* grab macros */
		grab_host_macros(temp_host);

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		host_name=temp_host->name;

		if(temp_host->icon_image!=NULL){
			process_macros(temp_host->icon_image,&processed_string,0);
			host_icon_image=processed_string;
		}

printf("\t\t\t{\n");
printf("\t\t\t\t\"host_name\":\"%s\",\n",host_name);
printf("\t\t\t\t\"host_icon_image\":\"%s\",\n",host_icon_image);
printf("\t\t\t\t\"services\":\n");
printf("\t\t\t\t[\n");

		/* display all services on the host */
		current_item=1;
		for(temp_service=service_list;temp_service;temp_service=temp_service->next){

			/* skip this service if it's not associate with the host */
			if(strcmp(temp_service->host_name,temp_host->name))
				continue;

			/* grab macros */
			grab_service_macros(temp_service);

			/* get the status of the service */
			temp_servicestatus=find_servicestatus(temp_service->host_name,temp_service->description);

			service_status=(temp_servicestatus==NULL)?0:(temp_servicestatus->status);
			service_host_name=temp_servicestatus->host_name;
			service_description=temp_servicestatus->description;

			current_item++;

printf("\t\t\t\t\t{\n");
printf("\t\t\t\t\t\t\"service_status\":%d,\n",service_status);
printf("\t\t\t\t\t\t\"service_description\":\"%s\",\n",service_description);
printf("\t\t\t\t\t\t\"service_host_name\":\"%s\"\n",service_host_name);
printf("\t\t\t\t\t},\n");
		}

printf("\t\t\t\t\t{}\n");
printf("\t\t\t\t],\n");


		/* actions */

		host_name=temp_host->name;
		
		if(temp_host->notes_url!=NULL){
			process_macros(temp_host->notes_url,&processed_string,0);
			host_notes_url=processed_string;
		}
		if(temp_host->action_url!=NULL){
			process_macros(temp_host->action_url,&processed_string,0);
			host_action_url=processed_string;
		}

printf("\t\t\t\t\"host_notes_url\":\"%s\",\n",host_notes_url);
printf("\t\t\t\t\"host_action_url\":\"%s\"\n",host_action_url);
printf("\t\t\t},\n");

	}

printf("\t\t\t{}\n");
printf("\t\t]\n");

printf("\t},\n");

	return;
}




/******************************************************************/
/**********  SERVICE SORTING & FILTERING FUNCTIONS  ***************/
/******************************************************************/


/* sorts the service list */
int sort_services(int s_type, int s_option){
	servicesort *new_servicesort;
	servicesort *last_servicesort;
	servicesort *temp_servicesort;
	servicestatus *temp_svcstatus;

	if(s_type==SORT_NONE)
		return ERROR;

	if(servicestatus_list==NULL)
		return ERROR;

	/* sort all services status entries */
	for(temp_svcstatus=servicestatus_list;temp_svcstatus!=NULL;temp_svcstatus=temp_svcstatus->next){

		/* allocate memory for a new sort structure */
		new_servicesort=(servicesort *)malloc(sizeof(servicesort));
		if(new_servicesort==NULL)
			return ERROR;

		new_servicesort->svcstatus=temp_svcstatus;

		last_servicesort=servicesort_list;
		for(temp_servicesort=servicesort_list;temp_servicesort!=NULL;temp_servicesort=temp_servicesort->next){

			if(compare_servicesort_entries(s_type,s_option,new_servicesort,temp_servicesort)==TRUE){
				new_servicesort->next=temp_servicesort;
				if(temp_servicesort==servicesort_list)
					servicesort_list=new_servicesort;
				else
					last_servicesort->next=new_servicesort;
				break;
		                }
			else
				last_servicesort=temp_servicesort;
	                }

		if(servicesort_list==NULL){
			new_servicesort->next=NULL;
			servicesort_list=new_servicesort;
	                }
		else if(temp_servicesort==NULL){
			new_servicesort->next=NULL;
			last_servicesort->next=new_servicesort;
	                }
	        }

	return OK;
        }


int compare_servicesort_entries(int s_type, int s_option, servicesort *new_servicesort, servicesort *temp_servicesort){
	servicestatus *new_svcstatus;
	servicestatus *temp_svcstatus;
	time_t nt;
	time_t tt;

	new_svcstatus=new_servicesort->svcstatus;
	temp_svcstatus=temp_servicesort->svcstatus;

	if(s_type==SORT_ASCENDING){

		if(s_option==SORT_LASTCHECKTIME){
			if(new_svcstatus->last_check < temp_svcstatus->last_check)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_CURRENTATTEMPT){
			if(new_svcstatus->current_attempt < temp_svcstatus->current_attempt)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_SERVICESTATUS){
			if(new_svcstatus->status <= temp_svcstatus->status)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTNAME){
			if(strcasecmp(new_svcstatus->host_name,temp_svcstatus->host_name)<0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_SERVICENAME){
			if(strcasecmp(new_svcstatus->description,temp_svcstatus->description)<0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_STATEDURATION){
			if(new_svcstatus->last_state_change==(time_t)0)
				nt=(program_start>current_time)?0:(current_time-program_start);
			else
				nt=(new_svcstatus->last_state_change>current_time)?0:(current_time-new_svcstatus->last_state_change);
			if(temp_svcstatus->last_state_change==(time_t)0)
				tt=(program_start>current_time)?0:(current_time-program_start);
			else
				tt=(temp_svcstatus->last_state_change>current_time)?0:(current_time-temp_svcstatus->last_state_change);
			if(nt<tt)
				return TRUE;
			else
				return FALSE;
		        }
	        }
	else{
		if(s_option==SORT_LASTCHECKTIME){
			if(new_svcstatus->last_check > temp_svcstatus->last_check)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_CURRENTATTEMPT){
			if(new_svcstatus->current_attempt > temp_svcstatus->current_attempt)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_SERVICESTATUS){
			if(new_svcstatus->status > temp_svcstatus->status)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTNAME){
			if(strcasecmp(new_svcstatus->host_name,temp_svcstatus->host_name)>0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_SERVICENAME){
			if(strcasecmp(new_svcstatus->description,temp_svcstatus->description)>0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_STATEDURATION){
			if(new_svcstatus->last_state_change==(time_t)0)
				nt=(program_start>current_time)?0:(current_time-program_start);
			else
				nt=(new_svcstatus->last_state_change>current_time)?0:(current_time-new_svcstatus->last_state_change);
			if(temp_svcstatus->last_state_change==(time_t)0)
				tt=(program_start>current_time)?0:(current_time-program_start);
			else
				tt=(temp_svcstatus->last_state_change>current_time)?0:(current_time-temp_svcstatus->last_state_change);
			if(nt>tt)
				return TRUE;
			else
				return FALSE;
		        }
	        }

	return TRUE;
        }



/* sorts the host list */
int sort_hosts(int s_type, int s_option){
	hostsort *new_hostsort;
	hostsort *last_hostsort;
	hostsort *temp_hostsort;
	hoststatus *temp_hststatus;

	if(s_type==SORT_NONE)
		return ERROR;

	if(hoststatus_list==NULL)
		return ERROR;

	/* sort all hosts status entries */
	for(temp_hststatus=hoststatus_list;temp_hststatus!=NULL;temp_hststatus=temp_hststatus->next){

		/* allocate memory for a new sort structure */
		new_hostsort=(hostsort *)malloc(sizeof(hostsort));
		if(new_hostsort==NULL)
			return ERROR;

		new_hostsort->hststatus=temp_hststatus;

		last_hostsort=hostsort_list;
		for(temp_hostsort=hostsort_list;temp_hostsort!=NULL;temp_hostsort=temp_hostsort->next){

			if(compare_hostsort_entries(s_type,s_option,new_hostsort,temp_hostsort)==TRUE){
				new_hostsort->next=temp_hostsort;
				if(temp_hostsort==hostsort_list)
					hostsort_list=new_hostsort;
				else
					last_hostsort->next=new_hostsort;
				break;
		                }
			else
				last_hostsort=temp_hostsort;
	                }

		if(hostsort_list==NULL){
			new_hostsort->next=NULL;
			hostsort_list=new_hostsort;
	                }
		else if(temp_hostsort==NULL){
			new_hostsort->next=NULL;
			last_hostsort->next=new_hostsort;
	                }
	        }

	return OK;
        }


int compare_hostsort_entries(int s_type, int s_option, hostsort *new_hostsort, hostsort *temp_hostsort){
	hoststatus *new_hststatus;
	hoststatus *temp_hststatus;
	time_t nt;
	time_t tt;

	new_hststatus=new_hostsort->hststatus;
	temp_hststatus=temp_hostsort->hststatus;

	if(s_type==SORT_ASCENDING){

		if(s_option==SORT_LASTCHECKTIME){
			if(new_hststatus->last_check < temp_hststatus->last_check)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTSTATUS){
			if(new_hststatus->status <= temp_hststatus->status)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTNAME){
			if(strcasecmp(new_hststatus->host_name,temp_hststatus->host_name)<0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_STATEDURATION){
			if(new_hststatus->last_state_change==(time_t)0)
				nt=(program_start>current_time)?0:(current_time-program_start);
			else
				nt=(new_hststatus->last_state_change>current_time)?0:(current_time-new_hststatus->last_state_change);
			if(temp_hststatus->last_state_change==(time_t)0)
				tt=(program_start>current_time)?0:(current_time-program_start);
			else
				tt=(temp_hststatus->last_state_change>current_time)?0:(current_time-temp_hststatus->last_state_change);
			if(nt<tt)
				return TRUE;
			else
				return FALSE;
		        }
	        }
	else{
		if(s_option==SORT_LASTCHECKTIME){
			if(new_hststatus->last_check > temp_hststatus->last_check)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTSTATUS){
			if(new_hststatus->status > temp_hststatus->status)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_HOSTNAME){
			if(strcasecmp(new_hststatus->host_name,temp_hststatus->host_name)>0)
				return TRUE;
			else
				return FALSE;
		        }
		else if(s_option==SORT_STATEDURATION){
			if(new_hststatus->last_state_change==(time_t)0)
				nt=(program_start>current_time)?0:(current_time-program_start);
			else
				nt=(new_hststatus->last_state_change>current_time)?0:(current_time-new_hststatus->last_state_change);
			if(temp_hststatus->last_state_change==(time_t)0)
				tt=(program_start>current_time)?0:(current_time-program_start);
			else
				tt=(temp_hststatus->last_state_change>current_time)?0:(current_time-temp_hststatus->last_state_change);
			if(nt>tt)
				return TRUE;
			else
				return FALSE;
		        }
	        }

	return TRUE;
        }



/* free all memory allocated to the servicesort structures */
void free_servicesort_list(void){
	servicesort *this_servicesort;
	servicesort *next_servicesort;

	/* free memory for the servicesort list */
	for(this_servicesort=servicesort_list;this_servicesort!=NULL;this_servicesort=next_servicesort){
		next_servicesort=this_servicesort->next;
		free(this_servicesort);
	        }

	return;
        }


/* free all memory allocated to the hostsort structures */
void free_hostsort_list(void){
	hostsort *this_hostsort;
	hostsort *next_hostsort;

	/* free memory for the hostsort list */
	for(this_hostsort=hostsort_list;this_hostsort!=NULL;this_hostsort=next_hostsort){
		next_hostsort=this_hostsort->next;
		free(this_hostsort);
	        }

	return;
        }



/* check host properties filter */
int passes_host_properties_filter(hoststatus *temp_hoststatus){

	if((host_properties & HOST_SCHEDULED_DOWNTIME) && temp_hoststatus->scheduled_downtime_depth<=0)
		return FALSE;

	if((host_properties & HOST_NO_SCHEDULED_DOWNTIME) && temp_hoststatus->scheduled_downtime_depth>0)
		return FALSE;

	if((host_properties & HOST_STATE_ACKNOWLEDGED) && temp_hoststatus->problem_has_been_acknowledged==FALSE)
		return FALSE;

	if((host_properties & HOST_STATE_UNACKNOWLEDGED) && temp_hoststatus->problem_has_been_acknowledged==TRUE)
		return FALSE;

	if((host_properties & HOST_CHECKS_DISABLED) && temp_hoststatus->checks_enabled==TRUE)
		return FALSE;

	if((host_properties & HOST_CHECKS_ENABLED) && temp_hoststatus->checks_enabled==FALSE)
		return FALSE;

	if((host_properties & HOST_EVENT_HANDLER_DISABLED) && temp_hoststatus->event_handler_enabled==TRUE)
		return FALSE;

	if((host_properties & HOST_EVENT_HANDLER_ENABLED) && temp_hoststatus->event_handler_enabled==FALSE)
		return FALSE;

	if((host_properties & HOST_FLAP_DETECTION_DISABLED) && temp_hoststatus->flap_detection_enabled==TRUE)
		return FALSE;

	if((host_properties & HOST_FLAP_DETECTION_ENABLED) && temp_hoststatus->flap_detection_enabled==FALSE)
		return FALSE;

	if((host_properties & HOST_IS_FLAPPING) && temp_hoststatus->is_flapping==FALSE)
		return FALSE;

	if((host_properties & HOST_IS_NOT_FLAPPING) && temp_hoststatus->is_flapping==TRUE)
		return FALSE;

	if((host_properties & HOST_NOTIFICATIONS_DISABLED) && temp_hoststatus->notifications_enabled==TRUE)
		return FALSE;

	if((host_properties & HOST_NOTIFICATIONS_ENABLED) && temp_hoststatus->notifications_enabled==FALSE)
		return FALSE;

	if((host_properties & HOST_PASSIVE_CHECKS_DISABLED) && temp_hoststatus->accept_passive_host_checks==TRUE)
		return FALSE;

	if((host_properties & HOST_PASSIVE_CHECKS_ENABLED) && temp_hoststatus->accept_passive_host_checks==FALSE)
		return FALSE;

	if((host_properties & HOST_PASSIVE_CHECK) && temp_hoststatus->check_type==HOST_CHECK_ACTIVE)
		return FALSE;

	if((host_properties & HOST_ACTIVE_CHECK) && temp_hoststatus->check_type==HOST_CHECK_PASSIVE)
		return FALSE;

	if((host_properties & HOST_HARD_STATE) && temp_hoststatus->state_type==SOFT_STATE)
		return FALSE;

	if((host_properties & HOST_SOFT_STATE) && temp_hoststatus->state_type==HARD_STATE)
		return FALSE;

	return TRUE;
        }



/* check service properties filter */
int passes_service_properties_filter(servicestatus *temp_servicestatus){

	if((service_properties & SERVICE_SCHEDULED_DOWNTIME) && temp_servicestatus->scheduled_downtime_depth<=0)
		return FALSE;

	if((service_properties & SERVICE_NO_SCHEDULED_DOWNTIME) && temp_servicestatus->scheduled_downtime_depth>0)
		return FALSE;

	if((service_properties & SERVICE_STATE_ACKNOWLEDGED) && temp_servicestatus->problem_has_been_acknowledged==FALSE)
		return FALSE;

	if((service_properties & SERVICE_STATE_UNACKNOWLEDGED) && temp_servicestatus->problem_has_been_acknowledged==TRUE)
		return FALSE;

	if((service_properties & SERVICE_CHECKS_DISABLED) && temp_servicestatus->checks_enabled==TRUE)
		return FALSE;

	if((service_properties & SERVICE_CHECKS_ENABLED) && temp_servicestatus->checks_enabled==FALSE)
		return FALSE;

	if((service_properties & SERVICE_EVENT_HANDLER_DISABLED) && temp_servicestatus->event_handler_enabled==TRUE)
		return FALSE;

	if((service_properties & SERVICE_EVENT_HANDLER_ENABLED) && temp_servicestatus->event_handler_enabled==FALSE)
		return FALSE;

	if((service_properties & SERVICE_FLAP_DETECTION_DISABLED) && temp_servicestatus->flap_detection_enabled==TRUE)
		return FALSE;

	if((service_properties & SERVICE_FLAP_DETECTION_ENABLED) && temp_servicestatus->flap_detection_enabled==FALSE)
		return FALSE;

	if((service_properties & SERVICE_IS_FLAPPING) && temp_servicestatus->is_flapping==FALSE)
		return FALSE;

	if((service_properties & SERVICE_IS_NOT_FLAPPING) && temp_servicestatus->is_flapping==TRUE)
		return FALSE;

	if((service_properties & SERVICE_NOTIFICATIONS_DISABLED) && temp_servicestatus->notifications_enabled==TRUE)
		return FALSE;

	if((service_properties & SERVICE_NOTIFICATIONS_ENABLED) && temp_servicestatus->notifications_enabled==FALSE)
		return FALSE;

	if((service_properties & SERVICE_PASSIVE_CHECKS_DISABLED) && temp_servicestatus->accept_passive_service_checks==TRUE)
		return FALSE;

	if((service_properties & SERVICE_PASSIVE_CHECKS_ENABLED) && temp_servicestatus->accept_passive_service_checks==FALSE)
		return FALSE;

	if((service_properties & SERVICE_PASSIVE_CHECK) && temp_servicestatus->check_type==SERVICE_CHECK_ACTIVE)
		return FALSE;

	if((service_properties & SERVICE_ACTIVE_CHECK) && temp_servicestatus->check_type==SERVICE_CHECK_PASSIVE)
		return FALSE;

	if((service_properties & SERVICE_HARD_STATE) && temp_servicestatus->state_type==SOFT_STATE)
		return FALSE;

	if((service_properties & SERVICE_SOFT_STATE) && temp_servicestatus->state_type==HARD_STATE)
		return FALSE;

	return TRUE;
        }

/* show a grid layout of hostgroup(s)... */
void show_mconf_hostgroup_grids(void){
	hostgroup *temp_hostgroup=NULL;
	int user_has_seen_something=FALSE;
	int hostgroup_error=FALSE;

printf("{\n");
printf("\t\"hostgroups\":\n");
printf("\t[\n");

	/* display status grids for all hostgroups */
	if(show_all_hostgroups==TRUE){

		/* loop through all hostgroups... */
		for(temp_hostgroup=hostgroup_list;temp_hostgroup!=NULL;temp_hostgroup=temp_hostgroup->next){

			/* make sure the user is authorized to view this hostgroup */
			if(is_authorized_for_hostgroup(temp_hostgroup,&current_authdata)==FALSE)
				continue;

			/* show grid for this hostgroup */
			show_mconf_hostgroup_grid(temp_hostgroup);

			user_has_seen_something=TRUE;
		}
	}

	/* else just show grid for a specific hostgroup */
	else{
		temp_hostgroup=find_hostgroup(hostgroup_name);
		if(temp_hostgroup==NULL)
			hostgroup_error=TRUE;
		else{
			show_mconf_hostgroup_grid(temp_hostgroup);
			user_has_seen_something=TRUE;
		}
	}

printf("\t\t{}\n");

printf("\t]\n");
printf("}\n");
	return;
}


/* displays status grid for a specific hostgroup */
void show_mconf_hostgroup_grid(hostgroup *temp_hostgroup){
	hostsmember *temp_member;
	char *status_bg_class="";
	char *host_status_class="";
	char *service_status_class="";
	host *temp_host;
	service *temp_service;
	hoststatus *temp_hoststatus;
	servicestatus *temp_servicestatus;
	char *processed_string=NULL;
	int current_item;
	char status[MAX_INPUT_BUFFER];
	time_t t;
	char date_time[MAX_DATETIME_LENGTH];

	char *host_name="";
	char *host_address="";
	char *host_status="";
	char *host_last_check="";
	char *service_description="";
	char *service_status="";
	char *service_last_check="";
	char *service_performance_data="";
	char *host_notes_url="";
	char *host_action_url="";
	customvariablesmember *temp_customvar=NULL;

printf("\t\t{\n");
printf("\t\t\t\"name\":\"%s\",\n",temp_hostgroup->group_name);
printf("\t\t\t\"alias\":\"%s\",\n",temp_hostgroup->alias);
printf("\t\t\t\"hosts\":\n");
printf("\t\t\t[\n");

	/* find all the hosts that belong to the hostgroup */
	for(temp_member=temp_hostgroup->members;temp_member!=NULL;temp_member=temp_member->next){

		/* find the host... */
		temp_host=find_host(temp_member->host_name);
		if(temp_host==NULL)
			continue;

		/* grab macros */
		grab_host_macros(temp_host);

		/* find the host status */
		temp_hoststatus=find_hoststatus(temp_host->name);
		if(temp_hoststatus==NULL)
			continue;

		host_name=temp_host->name;
		host_address=temp_host->address;

    /* get the last host check time */
		t=temp_hoststatus->last_check;
		get_time_string(&t,date_time,(int)sizeof(date_time),SHORT_DATE_TIME);
		if((unsigned long)temp_hoststatus->last_check==0L)
			strcpy(date_time,"N/A");
		host_last_check=date_time;

		if(temp_hoststatus->status==HOST_PENDING){
			strncpy(status,"PENDING",sizeof(status));
    } else if(temp_hoststatus->status==HOST_UP){
			strncpy(status,"UP",sizeof(status));
    } else if(temp_hoststatus->status==HOST_DOWN){
			strncpy(status,"DOWN",sizeof(status));
    } else if(temp_hoststatus->status==HOST_UNREACHABLE){
			strncpy(status,"UNREACHABLE",sizeof(status));
    }
		status[sizeof(status)-1]='\x0';
		host_status=status;

printf("\t\t\t\t{\n");
printf("\t\t\t\t\t\"name\":\"%s\",\n",host_name);
printf("\t\t\t\t\t\"address\":\"%s\",\n",host_address);
printf("\t\t\t\t\t\"status\":\"%s\",\n",host_status);
printf("\t\t\t\t\t\"last_check\":\"%s\",\n",host_last_check);

            temp_customvar=temp_host->custom_variables;
            while(temp_customvar!=NULL){
                printf("\t\t\t\t\t\"%s\":\"%s\", \n", temp_customvar->variable_name, temp_customvar->variable_value);
                temp_customvar=temp_customvar->next;
            }

printf("\t\t\t\t\t\"services\":\n");
printf("\t\t\t\t\t[\n");

		/* display all services on the host */
		current_item=1;
		for(temp_service=service_list;temp_service;temp_service=temp_service->next){

			/* skip this service if it's not associate with the host */
			if(strcmp(temp_service->host_name,temp_host->name))
				continue;

			/* grab macros */
			grab_service_macros(temp_service);

			/* get the status of the service */
			temp_servicestatus=find_servicestatus(temp_service->host_name,temp_service->description);

			service_description=temp_servicestatus->description;
			service_performance_data=(temp_servicestatus->perf_data==NULL)?"":html_encode(temp_servicestatus->perf_data,TRUE);

			/* get the last service check time */
			t=temp_servicestatus->last_check;
			get_time_string(&t,date_time,(int)sizeof(date_time),SHORT_DATE_TIME);
			if((unsigned long)temp_servicestatus->last_check==0L)
				strcpy(date_time,"N/A");
			service_last_check=date_time;
			
			/* create status string */
			if(temp_servicestatus->status==SERVICE_PENDING){
				strncpy(status,"PENDING",sizeof(status));
			} else if(temp_servicestatus->status==SERVICE_OK){
				strncpy(status,"OK",sizeof(status));
			} else if(temp_servicestatus->status==SERVICE_WARNING){
				strncpy(status,"WARNING",sizeof(status));
			} else if(temp_servicestatus->status==SERVICE_UNKNOWN){
				strncpy(status,"UNKNOWN",sizeof(status));
			} else if(temp_servicestatus->status==SERVICE_CRITICAL){
				strncpy(status,"CRITICAL",sizeof(status));
			}
			status[sizeof(status)-1]='\x0';
			service_status=status;

			current_item++;

printf("\t\t\t\t\t\t{\n");
printf("\t\t\t\t\t\t\t\"description\":\"%s\",\n",service_description);
printf("\t\t\t\t\t\t\t\"status\":\"%s\",\n",service_status);
printf("\t\t\t\t\t\t\t\"last_check\":\"%s\",\n",service_last_check);
printf("\t\t\t\t\t\t\t\"performance_data\":\"%s\"\n",service_performance_data);
printf("\t\t\t\t\t\t},\n");
		}

printf("\t\t\t\t\t\t{}\n");
printf("\t\t\t\t\t]\n");
printf("\t\t\t\t},\n");

	}

printf("\t\t\t\t{}\n");
printf("\t\t\t]\n");

printf("\t\t},\n");

	return;
}
