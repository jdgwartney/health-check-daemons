#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

struct Configuration
{
  int listeningPort;

};

typedef struct Configuration CONFIG; 


CONFIG configuration;
char * configFilePath = NULL;

    void daemonShutdown();
    void signal_handler(int sig);
    void daemonize(char *rundir, char *pidfile);

    int pidFilehandle;
    int listeningPort = 0;

    void signal_handler(int sig)
    {
        switch(sig)
        {
            case SIGHUP:
                syslog(LOG_WARNING, "Received SIGHUP signal.");
                break;
            case SIGINT:
            case SIGTERM:
                syslog(LOG_INFO, "Daemon exiting");
                daemonShutdown();
                exit(EXIT_SUCCESS);
                break;
            default:
                syslog(LOG_WARNING, "Unhandled signal %s", strsignal(sig));
                break;
        }
    }

    void daemonShutdown()
    {
        close(pidFilehandle);
    }

    void daemonize(char *rundir, char *pidfile)
    {
        int pid, sid, i;
        char str[10];
        struct sigaction newSigAction;
        sigset_t newSigSet;

        /* Check if parent process id is set */
        if (getppid() == 1)
        {
            /* PPID exists, therefore we are already a daemon */
            return;
        }

        /* Set signal mask - signals we want to block */
        sigemptyset(&newSigSet);
        sigaddset(&newSigSet, SIGCHLD);  /* ignore child - i.e. we don't need to wait for it */
        sigaddset(&newSigSet, SIGTSTP);  /* ignore Tty stop signals */
        sigaddset(&newSigSet, SIGTTOU);  /* ignore Tty background writes */
        sigaddset(&newSigSet, SIGTTIN);  /* ignore Tty background reads */
        sigprocmask(SIG_BLOCK, &newSigSet, NULL);   /* Block the above specified signals */

        /* Set up a signal handler */
        newSigAction.sa_handler = signal_handler;
        sigemptyset(&newSigAction.sa_mask);
        newSigAction.sa_flags = 0;

            /* Signals to handle */
            sigaction(SIGHUP, &newSigAction, NULL);     /* catch hangup signal */
            sigaction(SIGTERM, &newSigAction, NULL);    /* catch term signal */
            sigaction(SIGINT, &newSigAction, NULL);     /* catch interrupt signal */

        /* Fork*/
        pid = fork();

        if (pid < 0)
        {
            /* Could not fork */
            exit(EXIT_FAILURE);
        }

        if (pid > 0)
        {
            /* Child created ok, so exit parent process */
            printf("Child process created: %d\n", pid);
            exit(EXIT_SUCCESS);
        }

        /* Child continues */

        umask(027); /* Set file permissions 750 */

        /* Get a new process group */
        sid = setsid();

        if (sid < 0)
        {
            exit(EXIT_FAILURE);
        }

        /* close all descriptors */
        for (i = getdtablesize(); i >= 0; --i)
        {
            close(i);
        }

        /* Route I/O connections */

        /* Open STDIN */
        i = open("/dev/null", O_RDWR);

        /* STDOUT */
        dup(i);

        /* STDERR */
        dup(i);

        chdir(rundir); /* change running directory */

        /* Ensure only one copy */
        pidFilehandle = open(pidfile, O_RDWR|O_CREAT, 0600);

        if (pidFilehandle == -1 )
        {
            /* Couldn't open lock file */
            syslog(LOG_INFO, "Could not open PID lock file %s, exiting", pidfile);
            exit(EXIT_FAILURE);
        }

        /* Try to lock file */
        if (lockf(pidFilehandle,F_TLOCK,0) == -1)
        {
            /* Couldn't get lock on lock file */
            syslog(LOG_INFO, "Could not lock PID lock file %s, exiting", pidfile);
            exit(EXIT_FAILURE);
        }

        /* Get and format PID */
        sprintf(str,"%d\n",getpid());

        /* write pid to lockfile */
        write(pidFilehandle, str, strlen(str));
    }

    void processLoop()
    {
        int listenfd,connfd,n;
        struct sockaddr_in servaddr,cliaddr;
        socklen_t clilen;
        pid_t     childpid;
        char mesg[1000];

        listenfd=socket(AF_INET,SOCK_STREAM,0);

        bzero(&servaddr,sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr=htonl(INADDR_ANY);
        servaddr.sin_port=htons(configuration.listeningPort);
        bind(listenfd,(struct sockaddr *)&servaddr,sizeof(servaddr));

        listen(listenfd,1024);
        syslog(LOG_INFO,"Listener started");

        for(;;)
        {
            clilen=sizeof(cliaddr);
            connfd = accept(listenfd,(struct sockaddr *)&cliaddr,&clilen);

            if ((childpid = fork()) == 0)
            {
                close (listenfd);

                for(;;)
                {
                    n = recvfrom(connfd,mesg,1000,0,(struct sockaddr *)&cliaddr,&clilen);
                    sendto(connfd,mesg,n,0,(struct sockaddr *)&cliaddr,sizeof(cliaddr));
                    printf("-------------------------------------------------------\n");
                    mesg[n] = 0;
                    printf("Received the following:\n");
                    printf("%s",mesg);
                    printf("-------------------------------------------------------\n");
                }
         
            }
            close(connfd);
        }
    }

    void usage(char * programName)
    {
        fprintf(stderr,"usage: %s -f config_file\n",programName);
        exit(0);
    }

    int getKeyValuePair(char *line,char *key,char *value)
    {
        char * lKey;
        char * lValue;
        lKey = strtok_r(line,":",&lValue);
        strcpy(key,lKey);
        strcpy(value,lValue);
        return !(key && value);
    }

    int getParameter(char *line,CONFIG * config) 
    {
        char test[80], blah[80];
        char *sep = "\\/:;=-";
        char lline[MAX_CANON+1];
        char key[MAX_CANON+1];
        char value[MAX_CANON+1];
        int result = 0;

        strcpy(lline,line);

        result = getKeyValuePair(lline,key,value);
/*
        fprintf(stdout,"key: %s\n",key);
        fprintf(stdout,"value: %s\n",value);
*/

        /*
         * TODO: Match the key to the configuration structure
         * TODO: Ignoring result from getting key value pair
         */
         config->listeningPort = atoi(value);

        return result;
    }

    int loadConfiguration(char * filePath,CONFIG * config)
    {
      FILE *fp = NULL;
      struct stat fileStat;
      char line[MAX_CANON+1];
      int result = 0;


      syslog(LOG_INFO,"Reading configuration file");

      if(!lstat(filePath,&fileStat))
      {
/*          fprintf(stdout,"size = %lld\n",fileStat.st_size);*/
      }

      fp = fopen(filePath,"r");
      if (fp)
      {
          do
          {
             fread(line,1024,1,fp);
             getParameter(line,config);
          } while(!feof(fp));
      }
      else 
      {
         fprintf (stderr, "Couldn't open file %s; %s\n",filePath, strerror (errno));
         result = errno;
      }
      if (fp)
      {
         fclose(fp);
      }
      return result;
    }

    int handleCommandLineArguments(int argc,char *argv[])
    {
       int aflag = 0;
       int bflag = 0;
       char * cvalue = NULL;
       char c;
       int index = 0;
       int result = 1;

       opterr = 0;

       while ((c = getopt (argc, argv, "hf:")) != -1)
         switch (c)
           {
           case 'h':
             usage(basename(argv[0]));
             break;
           case 'f':
             configFilePath = optarg;
             break;
           case '?':
             if (optopt == 'c')
               fprintf (stderr, "Option -%c requires an argument.\n", optopt);
             else if (isprint (optopt))
               fprintf (stderr, "Unknown option `-%c'.\n", optopt);
             else
               fprintf (stderr,
                        "Unknown option character `\\x%x'.\n",
                        optopt);
             return 1;
           default:
             abort();
           }
/*       printf ("aflag = %d, bflag = %d, cvalue = %s\n",aflag, bflag, cvalue); */
     
       for (index = optind; index < argc; index++)
       {
           /*printf ("Non-option argument %s\n", argv[index]); */
       }

       if (configFilePath)
       {
          result = 0;
       }

       return result;
    }
    
    int main(int argc, char * argv[])
    {
        char * programName = basename(argv[0]);
        int result = 0;

	if (handleCommandLineArguments(argc,argv)) {
            usage(programName);
        }

        fprintf(stdout,"file path: %s\n",configFilePath);
	result = loadConfiguration(configFilePath,&configuration);
	if (result)
        {
           exit(result);
        }
        fprintf(stdout,"port %d\n",configuration.listeningPort);

        /* Debug logging
        setlogmask(LOG_UPTO(LOG_DEBUG));
        openlog(DAEMON_NAME, LOG_CONS, LOG_USER);
        */

        /* Logging */
        setlogmask(LOG_UPTO(LOG_INFO));
        openlog(programName, LOG_CONS | LOG_PERROR, LOG_USER);

        syslog(LOG_INFO, "Daemon starting up");

        /* Deamonize */
        daemonize("/tmp/", "/tmp/daemon.pid");

        syslog(LOG_INFO, "Daemon running");

        while (1)
        {
            syslog(LOG_INFO, "daemon says hello");
            processLoop();
        }
        return result;
    }
