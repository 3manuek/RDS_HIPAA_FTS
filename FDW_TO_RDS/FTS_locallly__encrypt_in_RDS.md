# FTS locally, encrypt remotely in RDS using official tools with PostgreSQL

I've been dealing with an issue that came into my desktop from people of the
community, regarding RDS and HIPPA rules. There was a confusing scenario whether
PostgreSQL was used with FTS and encryption on RDS. There are a lot of details
regarding the architecture, however I think it won't be necessary to dig into
very deeply to understand the basics of the present article moto.

HIPPA rules are way complex. tl;dr, they tell us to store data encrypted on
servers that are not in the premises. And that's the case of RDS. There is something
that we need to understand regarding RDS: that magic comes with some caveats.
AS you may know, encryption came at a cost, specially on CPU usage. vCPU sometimes
does not have the expected performance, making it a valuable resource.
