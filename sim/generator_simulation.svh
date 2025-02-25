/* The generator class has three primary functions in the simulation environment

    1. It takes work queue entries from sq_rd and sq_wr and parses them into a mailbox message for the correct driver process
    2. It reads the input files passed from tb_user and generates matching work queue entries in rq_rd and rq_wr, simulating incoming RDMA requests,
        or it generates a prompt to the host driver to send data via AXI4 streams in case the simulation needs data from the host without accompanying work queue entries.
    3. It generates cq_rd and cq_wr transactions according to the feedback of the driver classes
    */

class generator_simulation;

    mailbox acks;
    mailbox host_mem_rd[N_STRM_AXI];
    mailbox host_mem_wr[N_STRM_AXI];
    mailbox host_recv[N_STRM_AXI];
    mailbox card_mem_rd[N_CARD_AXI];
    mailbox card_mem_wr[N_CARD_AXI];
    mailbox rdma_strm_rreq_recv[N_RDMA_AXI];
    mailbox rdma_strm_rreq_send[N_RDMA_AXI];
    mailbox rdma_strm_rrsp_recv[N_RDMA_AXI];
    mailbox rdma_strm_rrsp_send[N_RDMA_AXI];

    c_meta #(.ST(req_t)) sq_rd;
    c_meta #(.ST(req_t)) sq_wr;
    c_meta #(.ST(ack_t)) cq_rd;
    c_meta #(.ST(ack_t)) cq_wr;
    c_meta #(.ST(req_t)) rq_rd;
    c_meta #(.ST(req_t)) rq_wr;

    string path_name;
    string rq_rd_file;
    string rq_wr_file;
    string host_input_file;

    event done_rq_rd;
    event done_rq_wr;
    event done_host_input;

    function new(
        mailbox mail_ack,
        mailbox host_mem_strm_rd[N_STRM_AXI],
        mailbox host_mem_strm_wr[N_STRM_AXI],
        mailbox host_recv_mail[N_STRM_AXI],
        mailbox card_mem_strm_rd[N_CARD_AXI],
        mailbox card_mem_strm_wr[N_CARD_AXI],
        mailbox mail_rdma_strm_rreq_recv[N_RDMA_AXI],
        mailbox mail_rdma_strm_rreq_send[N_RDMA_AXI],
        mailbox mail_rdma_strm_rrsp_recv[N_RDMA_AXI],
        mailbox mail_rdma_strm_rrsp_send[N_RDMA_AXI],
        c_meta #(.ST(req_t)) sq_rd_drv,
        c_meta #(.ST(req_t)) sq_wr_drv,
        c_meta #(.ST(ack_t)) cq_rd_drv,
        c_meta #(.ST(ack_t)) cq_wr_drv,
        c_meta #(.ST(req_t)) rq_rd_drv,
        c_meta #(.ST(req_t)) rq_wr_drv,
        string input_path,
        string rq_rd_file_name,
        string rq_wr_file_name,
        string host_input_file_name
    );
        acks = mail_ack;
        host_mem_rd = host_mem_strm_rd;
        host_mem_wr = host_mem_strm_wr;
        host_recv = host_recv_mail;
        card_mem_rd = card_mem_strm_rd;
        card_mem_wr = card_mem_strm_wr;
        rdma_strm_rreq_recv = mail_rdma_strm_rreq_recv;
        rdma_strm_rreq_send = mail_rdma_strm_rreq_send;
        rdma_strm_rrsp_recv = mail_rdma_strm_rrsp_recv;
        rdma_strm_rrsp_send = mail_rdma_strm_rrsp_send;

        sq_rd = sq_rd_drv;
        sq_wr = sq_wr_drv;
        cq_rd = cq_rd_drv;
        cq_wr = cq_wr_drv;
        rq_rd = rq_rd_drv;
        rq_wr = rq_wr_drv;

        path_name = input_path;
        rq_rd_file = rq_rd_file_name;
        rq_wr_file = rq_wr_file_name;
        host_input_file = host_input_file_name;
    endfunction


    task initialize();
        sq_rd.reset_s();
        sq_wr.reset_s();
        cq_rd.reset_m();
        cq_wr.reset_m();
        rq_rd.reset_m();
        rq_wr.reset_m();
        rq_rd.reset_s();
        rq_wr.reset_s();
    endtask


    task run_sq_rd_recv();
        forever begin
            c_trs_req trs = new();
            sq_rd.recv(trs.data);

            trs.req_time = $realtime;

            // transfer request to the correct driver
            if (trs.data.strm == STRM_CARD) begin
                card_mem_rd[trs.data.dest].put(trs);
            end
            else if (trs.data.strm == STRM_HOST) begin
                host_mem_rd[trs.data.dest].put(trs);
            end
            else if (trs.data.strm == STRM_TCP) begin
                $display("TCP Interface Simulation is not yet supported!");
            end
            else if (trs.data.strm == STRM_RDMA) begin
                rdma_strm_rreq_recv[trs.data.dest].put(trs);
            end

            $display("run_sq_rd_recv, addr: %x, length: %d, opcode: %d, pid: %d, strm: %d, mode: %d, rdma: %d, remote: %d", trs.data.vaddr, trs.data.len, trs.data.opcode, trs.data.pid, trs.data.strm, trs.data.mode, trs.data.rdma, trs.data.remote);
        end
    endtask

    task run_sq_wr_recv();
        forever begin
            c_trs_req trs = new();
            sq_wr.recv(trs.data);

            trs.req_time = $realtime;

            // transfer request to the correct driver
            if (trs.data.strm == STRM_CARD) begin
                card_mem_wr[trs.data.dest].put(trs);
            end
            else if (trs.data.strm == STRM_HOST) begin
                host_mem_wr[trs.data.dest].put(trs);
            end
            else if (trs.data.strm == STRM_TCP) begin
                $display("TCP Interface Simulation is not yet supported!");
            end
            else if (trs.data.strm == STRM_RDMA) begin
                rdma_strm_rreq_send[trs.data.dest].put(trs);
            end
            $display("run_sq_wr_recv, addr: %x, length: %d, opcode: %d, pid: %d, strm: %d, mode: %d, rdma: %d, remote: %d", trs.data.vaddr, trs.data.len, trs.data.opcode, trs.data.pid, trs.data.strm, trs.data.mode, trs.data.rdma, trs.data.remote);
        end
    endtask

    task run_rq_rd_write(string path_name, string file_name);
        req_t rq_trs;
        c_trs_req mailbox_trs;
        int delay;
        string full_file_name;
        int FILE;
        string line;

        //open file descriptor
        full_file_name = {path_name, file_name};
        FILE = $fopen(full_file_name, "r");

        //read a single line, create rq_trs and mailbox_trs and initiate transfers after waiting for the specified delay
        while($fgets(line, FILE)) begin
            rq_trs = 0;
            $sscanf(line, "%x %h %h", delay, rq_trs.len, rq_trs.vaddr);

            rq_trs.opcode = 5'h10; //RDMA opcode for read_only
            rq_trs.host = 1'b1;
            rq_trs.actv = 1'b1;
            rq_trs.last = 1'b1;
            rq_trs.rdma = 1'b1;
            rq_trs.mode = 1'b1;

            mailbox_trs = new();
            mailbox_trs.data = rq_trs;

            #delay;

            rq_rd.send(rq_trs);
            mailbox_trs.req_time = $realtime;
            rdma_strm_rrsp_send[0].put(mailbox_trs);
        end

        //wait for mailbox to clear
        while(rdma_strm_rrsp_send[0].num() != 0) begin
            #100;
        end

        $display("RQ_RD DONE");
        -> done_rq_rd;
    endtask

    task run_rq_wr_write(string path_name, string file_name);
        //read input file -> delay -> write to rq_wr
        //delay, length, vaddr
        req_t rq_trs;
        c_trs_req mailbox_trs;
        int delay;
        string full_file_name;
        int FILE;
        string line;

        //open file descriptor
        full_file_name = {path_name, file_name};
        FILE = $fopen(full_file_name, "r");

        //read a single line, create rq_trs and mailbox_trs and initiate transfers after waiting for the specified delay
        while($fgets(line, FILE)) begin
            rq_trs = 0;
            $sscanf(line, "%x %h %h", delay, rq_trs.len, rq_trs.vaddr);

            rq_trs.opcode = 5'h0a; //RDMA opcode for read_only
            rq_trs.host = 1'b1;
            rq_trs.actv = 1'b1;
            rq_trs.last = 1'b1;
            rq_trs.rdma = 1'b1;
            rq_trs.mode = 1'b1;

            mailbox_trs = new();
            mailbox_trs.data = rq_trs;

            #delay;

            rq_wr.send(rq_trs);
            mailbox_trs.req_time = $realtime;
            rdma_strm_rrsp_recv[0].put(mailbox_trs);
        end

        //wait for mailbox to clear
        while(rdma_strm_rrsp_recv[0].num() != 0) begin
            #100;
        end

        $display("RQ_WR DONE");
        -> done_rq_wr;
    endtask

    task run_host_input(string path_name, string file_name);
        c_trs_strm_data trs;
        int dest;
        int delay;
        int FILE;
        string full_file_name; 
        string line;

        //open file descriptor
        full_file_name = {path_name, file_name};
        FILE = $fopen(full_file_name, "r");

        //read a single line, create trs and initiate transfer after waiting for the specified delay
        while($fgets(line, FILE)) begin
            trs = new();
            $sscanf(line, "%x %x %h %h %h %h", delay, dest, trs.pid, trs.keep, trs.last, trs.data);

            #delay;

            host_recv[dest].put(trs);
        end

        //wait for mailbox to clear
        for(int i = 0; i < N_STRM_AXI; i++)begin
            while(host_recv[i].num() != 0) begin end
        end
        
        $display("HOST_INPUT_DONE");
        -> done_host_input;
    endtask

    task run_gen();
        fork
            run_sq_rd_recv();
            run_sq_wr_recv();
            run_host_input(path_name, host_input_file);
            `ifdef EN_RDMA
                run_rq_rd_write(path_name, rq_rd_file);
            `endif
            `ifdef EN_NET
                run_rq_wr_write(path_name, rq_wr_file);
            `endif
        join_any
    endtask

    task run_ack();
        forever begin
            c_trs_ack trs = new(0, 0, 0, 0, 0, 0, 0, 0);
            ack_t data;

            acks.get(trs);

            data.opcode = trs.opcode;
            data.strm = trs.strm;
            data.remote = trs.remote;
            data.host = trs.host;
            data.dest = trs.dest;
            data.pid = trs.pid;
            data.vfid = trs.vfid;
            data.rsrvd = 0;

            if (trs.rd) begin
                $display("Ack: read, opcode=%d, strm=%d, remote=%d, host=%d, dest=%d, pid=%d, vfid=%d", data.opcode, data.strm, data.remote, data.host, data.dest, data.pid, data.vfid);
                cq_rd.send(data);
            end
            else begin
                $display("Ack: write, opcode=%d, strm=%d, remote=%d, host=%d, dest=%d, pid=%d, vfid=%d", data.opcode, data.strm, data.remote, data.host, data.dest, data.pid, data.vfid);
                cq_wr.send(data);
            end
        end
    endtask

endclass
