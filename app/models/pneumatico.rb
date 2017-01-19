class Pneumatico < ActiveRecord::Base
    
    def self.add_to_db(query_list, max_results, stagione = "Tutte")
        
        
        @fintyre = "http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp"
        @farnesepneus = "http://www.b2b.farnesepneus.it/check-prices"
        @centrogomme = "http://ordini.centrogomme.com/views/B2BCG/BB.view.php?page=ricerca"
        @cdp = "http://www.cdpgroupspa.com/"
        @multitires = "http://multitires.autotua.it/interna.asp"
        @maxtyre = "http://web.maxtyre.it/"
        @pendingomme = "http://www.pendingomme.it/login"
        @pneushopping = "http://www.pneushopping.it/"
        fornitori = []
        Fornitore.where(status: "Attivo").each do |f|
          fornitori.push(f.nome)
        end
        
        query_list.each do |query|
          puts ( Time.now - query.updated_at )/60
          if ( Time.now - query.updated_at )/60 > 10
              
            
            puts query
            threads = []
            
            # PNEUSHOPPING.IT
            
            if fornitori.include? "PneuShopping"
              
                begin
                  Pneumatico.search_pneushopping(query,stagione,max_results)
                ensure
                  ActiveRecord::Base.connection_pool.release_connection
                end
              
            end
            
            # PENDINGOMME.IT
            if fornitori.include? "PendinGomme"
              threads << Thread.new {
                begin
                  search_pendingomme(query,stagione,max_results)
                ensure
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            
            # FARNESEPNEUS.IT
            if fornitori.include? "FarnesePneus"
              threads << Thread.new {
                begin
                  search_farnese(query,stagione,max_results)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
              
            # FINTYRE.IT
            if fornitori.include? "Fintyre"
              threads << Thread.new {
                begin
                  search_fintyre(query,stagione,max_results)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            threads.each(&:join)
            
            threads2 = []
            # CENTRO GOMME
            if fornitori.include? "CentroGomme"
              threads2 << Thread.new {
                begin
                  search_centrogomme(query,stagione,max_results)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            
            # MULTITYRES
            if fornitori.include? "MultiTyre"
              threads2 << Thread.new {
                begin
                  search_multityre(query, stagione, max_results)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
              
            # MAXTYRE
            if fornitori.include? "MaxTyre"
              threads2 << Thread.new {
                begin
                  search_maxtyre(query, stagione, max_results)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            threads2.each(&:join)
            @query = query.to_s
          end
        end
        %x{for pid in $(ps -ef | awk '/phantomjs/ {print $2}'); do kill -9 $pid; done}
        Search.where(misura: @query).first.update(finished: true)
    end

private

    def self.sureLoadLink(mytimeout)
        browser_loaded=0
        i=0
        while (browser_loaded == 0)
            if i<4
                begin
                  browser_loaded=1
                  Timeout::timeout(mytimeout)  do
                    yield
                  end
                rescue Timeout::Error => e
                  puts "Page load timed out: #{e}"
                  browser_loaded=0
                  retry
                end
            else
                puts "failed to load resource"
                break
            end
            i+=1
        end
    end
    
    
  def self.search_pneushopping(query, stagione, max_results)
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    Pneumatico.sureLoadLink(10){ browser.goto 'http://www.pneushopping.it/login?_next=/' }
    query_old = query           
    puts "page loaded"
    if query.to_s.length > 7
      query = query.to_s[0..-2]+"."+query.to_s.last
    end
    fornitore_pneushopping = Fornitore.where(nome: "PneuShopping").first
    browser.text_field(:name => 'username').set fornitore_pneushopping.user_name
    browser.text_field(:name => 'password').set fornitore_pneushopping.password
    browser.button(:class => 'btn').click           
    puts "login effettuato"
    #browser.link(:href => '/catalogo').click
    browser.goto "http://www.pneushopping.it/catalogo"
    puts "pagina risultati"
    
    sleep 1
    
    
    browser.link(:class => 'btn btn-default buttons-collection buttons-colvis').click
    
    browser.ul(:class => 'dt-button-collection dropdown-menu fixed three-column').links.each do |li|
      if li.text == "Stagione"
        li.click
        browser.link(:class => 'btn btn-default buttons-collection buttons-colvis').click
        break
      end
    end
    
    browser.text_field(:class => 'form-control input-sm').set query
    
    
    
    sleep 0.5
    table = browser.table(:id => 'Grid').tbody

    
    if table.td(:class => 'dataTables_empty').exists?
      puts "nessun risultato per PneuShopping"
      browser.close
    end
    File.open('pages/pneushopping.html', 'w') {|f| f.write table.html }
    
    
    
    browser.ul(:class => 'pagination').links.each do |link|
      if link.text == '2'
        link.click
        sleep 0.5
        puts "Second Page"
        table2 = browser.table(:id => 'Grid').tbody
        File.open('pages/pneushopping.html', 'a') {|f| f.write table2.html }
      end
    end
    puts "closing Watir"
    browser.close
    
    file = File.open('pages/pneushopping.html', 'r')
    document = Nokogiri::HTML(file)
    tmp = query_old.to_s[0..2]+"/"+query_old.to_s[3..-1]
    document.css('tr').each do |row|
      puts "PneuShopping:" + row.text
      misura = row.css('td')[1].text + "/" + row.css('td')[2].text
      if query.to_s.length > 7
        raggio = row.css('td')[3].text[0..1]+row.css('td')[3].text.last
      else
        raggio = row.css('td')[3].text
      end
      marca = row.css('td')[4].text 
      cod_vel = row.css('td')[6].text+row.css('td')[7].text
      modello = misura+" "+raggio+" "+marca+" "+row.css('td')[5].text+" "+cod_vel
      #puts row.css('td.sorting_1').text[3..-1]
      prezzo_netto = row.css('td.sorting_1').text[3..-1].strip.gsub(",",".").to_f.round(2)
      giacenza = row.css('td')[9].text
      stag = row.css('td')[14].text
      if stag == "All Season"
        stag = "4 Stagioni"
      end
      misura_totale = misura+raggio
      puts misura_totale
      puts tmp
      if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
          Pneumatico.create(nome_fornitore: "PneuShopping", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @pneushopping, prezzo_netto: prezzo_netto, giacenza: giacenza, stagione: stag, cod_vel: cod_vel)
      end
    end
    
    file.close
  end
  
  def self.search_pendingomme(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    Pneumatico.sureLoadLink(10){ browser.goto 'http://www.pendingomme.it/login' }
               
    puts "page loaded"
    
    fornitore_pendingomme = Fornitore.where(nome: "PendinGomme").first
    browser.text_field(:name => 'email').set fornitore_pendingomme.user_name
                
    browser.text_field(:name => 'passwd').set fornitore_pendingomme.password
               
    browser.button(:name => 'SubmitLogin').click
      
    sleep 1
      
    puts "logged in"
    Pneumatico.sureLoadLink(10) { browser.goto('http://www.pendingomme.it/ricerca?controller=search&orderby=position&orderway=desc&search_query='+query.to_s+'&submit_search=') }

    if browser.element(:class => 'alert-warning').present?
      puts "nessun resultato per PendinGomme"
      browser.close
      return
    end
      
    File.open('pages/pendingomme.html', 'w') {|f| f.write browser.ul(:class => 'product_list').html }
   
    puts "PendinGomme: closing Watir"
    browser.close
    
    file = File.open('pages/pendingomme.html', 'r')
    document = Nokogiri::HTML(file)
    tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
    puts tmp
    document.css('ul li').each do |row|
      line = row.css('h5').text.strip
        
      marca = line.split(" ").first
      misura = line.split("(").last.split(")").first[0..4]
      if query.to_s.length > 7
        raggio = line.split("(").last.split(")").first[5..-1]
      else
        raggio = line.split("(").last.split(")").first[5..6]
      end
      
     
      stagione = row.css('p').text.strip.split("Stagione: ").last.split(",").first
      prezzo_netto = row.css(".price").text.strip.gsub(",",".").gsub(" €","").to_f.round(2)
      giacenza = row.css("#pQuantityAvailable").text.strip.split(" ").first.to_i
      
      cod_vel = row.css('p').text.strip.split("LI: ").last.split(",").first + row.css('p').text.strip.split("SI: ").last.split(",").first 
      
       modello = misura[0..2]+"/"+misura[3..-1]+" "+"R"+raggio+" "+marca+" "+line.split(" ").second.strip+" "+cod_vel
       
       puts "PendinGomme: "+modello
      if stagione == "All Season"
        stagione = "4 Stagioni"
      end
      if misura[3]!="/"
        misura = misura[0..2]+"/"+misura[3..-1]
      end
      misura_totale = misura+raggio
      
      if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
        Pneumatico.create(nome_fornitore: "PendinGomme", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @pendingomme, prezzo_netto: prezzo_netto, giacenza: giacenza, stagione: stagione, cod_vel: cod_vel)
      end
        
    end
    file.close
    
  end
  
  def self.search_farnese(query,stagione,max_results)
    
    marche_pneumatici = {}
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      marche_pneumatici[option["value"]] = option.text
    end
    file_pneumatici.close
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    Pneumatico.sureLoadLink(10){ browser.goto 'http://www.b2b.farnesepneus.it/' }
             
    puts "page loaded"
    fornitore_farnese = Fornitore.where(nome: "FarnesePneus").first
    browser.text_field(:name => '_username').set fornitore_farnese.user_name
              
    browser.text_field(:name => '_password').set fornitore_farnese.password
             
    browser.button(:name => '_submit').click
    browser.link(:text =>"Ricerca").click
      
      puts "login effettuato"
      #browser.select_list(:name => 'price-list_length').select 100
    
    element = browser.tr(:class => 'even')
    
    flag = Pneumatico.try_until(browser, @farnesepneus, element) {
      browser.select_list(:id => 'season-search').select stagione
      
      browser.text_field(:id => 'fast-search').set query
      #browser.text_field(:id => 'coupled').set query_accoppiata
      
      browser.button(:type => 'submit').click
      
      sleep 0.25
      
      # MODO ALTERNATIVO PER ATTENDERE IL CARICAMENTO DEI RISULTATI IN MANIERA SICURA 
      
      while browser.div(:id=>"price-list_processing").visible? do 
        sleep 1 
      end
      
      #browser.tr(:class => 'even').wait_until_present(timeout: 5)
      
      if browser.td(:class => 'dataTables_empty').exists?
        puts "no results for farnese"
        browser.close
        return false
      end
      
      
    }
    puts flag 
    if flag 
      table = browser.table(:id => 'price-list')
      File.open('pages/farnesepneus.html', 'w') {|f| f.write table.html }
   
      puts "Farnese: closing Watir"
      browser.close
   
      file = File.open('pages/farnesepneus.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
      i = 0
      document.css('tbody tr').each do |row|
        if i < max_results
          modello = row.css('.row-description').text.strip.gsub("-","R").gsub("CAM.","").gsub("COP.","").gsub(",",".")
          puts "FarnesePneus: "+ modello
          misura = modello.split("R",2).first.strip
          marca_tmp = row.css('td.row-manufacturer img').first['src'].split("/").last.split('.').first.to_i.to_s
          marca = marche_pneumatici[marca_tmp]
          if marca.nil?
            marca = modello.split("R",2).second.split(" ").second.split(" ").first
          end
         
          raggio = modello.split("R",2).second.split(" ").first.gsub(".","")
          if row.css('.row-season img').first['src'] != ""
            stagione = row.css('.row-season img').first['src'].split("/").last.split(".").first
          else
            stagione = "Inverno"
          end
          
          if stagione == "summer"
            stagione_db = "Estate"
          elsif stagione == "winter"
            stagione_db = "Inverno"
          else
            stagione_db = "4 Stagioni"
          end
            
          p_netto = row.css('.row-net-price').text.strip.gsub(",",".").to_f.round(2)
                    
          stock = row.css('.row-stock-column-1').text.strip.to_i + row.css('.row-stock-column-4').text.to_i
          
          misura_totale = misura+raggio
        
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "FarnesePneus", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @farnesepneus, prezzo_netto: p_netto, giacenza: stock, stagione: stagione_db)
            i+=1
          end
        end
      end
      file.close
    else
      browser.close
      puts "No results for Farnese"
    end
  end
  
  
  def self.search_fintyre(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    
    Pneumatico.sureLoadLink(10){
      browser.goto 'http://b2b.fintyre.it'
    }
    fornitore_fintyre = Fornitore.where(nome: "Fintyre").first
    browser.text_field(:id => 'username').set fornitore_fintyre.user_name
            
    browser.text_field(:id => 'password').set fornitore_fintyre.password
            
           
    browser.button(:id => 'id_submit').click
          
    search_page = 'http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp'  
            
    Pneumatico.sureLoadLink(15){ browser.goto search_page}
         
    element = browser.table(:id => 'result')
    
    flag = Pneumatico.try_until(browser, search_page , element) {
    
      browser.text_field(:id => 'id_ricerca').set query
      
      #browser.text_field(:id => 'id_ricerca2').set query_accoppiata
      
      if stagione == "Estate"
        id = "Solo estive"
      elsif stagione == "Inverno"
        id = "Solo invernali"
      elsif stagione == "4 Stagioni"
        id = "Solo 4 stagioni"
      end
      
      if stagione != "Tutte"
        browser.select_list(:id => 'id_copertura').select id
      end
      browser.button(:id => 'id_imgRicerca').click
      
      # SE NON DOVESSE FUNZIONARE TORNARE ALL'IMPOSTAZIONE PRECEDENTE CON SLEEP 5 E WAIT SOTTO A NESSUN RISULTATO
      sleep 0.25
      while browser.div(:class=>"modal").visible? do 
        sleep 1 
      end
      
      if browser.table(:id => 'result').span(:class => 'infoBanner').exists?
        puts "no results for fintyre"
        browser.close
        return false
      end
      
      browser.table(:id => 'result').wait_until_present(timeout: 5)
    }
    if flag 
            
      File.open('pages/fintyre.html', 'w') {|f| f.write browser.table(:id => 'result').html }
              
      browser.close
      browser.quit
              
      file = File.open('pages/fintyre.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
      i = 0
      document.css('tbody tr').each do |row|
        begin
        if (i<max_results && row.css('td.descrizione').text != "")
          marca = row.css('span.logoMarca').text.strip
          
          if row.css("td")[2].text.strip != nil
            cod_vel = row.css("td")[2].text.strip
            modello = row.css('td.descrizione').text.strip+" "+cod_vel
          else
            cod_vel = ""
            modello = row.css('td.descrizione').text.strip
          end
          temp = '#id_listino'+i.to_s
          prezzo_netto = row.css('.netnet').text.gsub(",",".").to_f.round(2)
          stock = 0
          if row.css('.dispCompleta').present?
            row.css('.dispCompleta').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          else
            row.css('.dispParziale').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          end
          puts "Fintyre: "+modello
          if (modello[6] != "R" && modello[7] != "R")
            raggio = modello.split(" ").second.split(" ").first
            misura = modello[0..5]
          else
            raggio = modello.split("R").second.split(" ").first
            misura = modello.split("R").first.strip.gsub("Z","")
          end
          if row.css('span.eti._4stagioni').present?
            stagione = "4 Stagioni"
          elsif row.css('span.eti._invernale').present?
            stagione = "Inverno"
          else
            stagione = "Estate"
          end
          
        
          misura_totale = misura+raggio
          
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "Fintyre",marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @fintyre, prezzo_netto: prezzo_netto, giacenza: stock, stagione: stagione)
            i+=1
          end
        end
        rescue NoMethodError
          puts "error"
          next
        end
      end
      file.close    
    else
      browser.close
      puts "No results for Fintyre"
    end
  end
  
  
  def self.search_centrogomme(query,stagione,max_results)
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
            
    Pneumatico.sureLoadLink(10){ browser.goto 'http://www.centrogomme.com/' }
           
    fornitore_centrogomme = Fornitore.where(nome: "CentroGomme").first
    browser.iframe.text_field(:id => 't_username').set fornitore_centrogomme.user_name
            
    browser.iframe.text_field(:id => 't_pwd').set fornitore_centrogomme.password
           
    browser.iframe.button(:type => 'submit').click
            
    search_page = "http://ordini.centrogomme.com/views/B2BCG/BB.view.php?page=ricerca"
    Pneumatico.sureLoadLink(10){ browser.goto search_page }
    element = browser.table(:id => 'searchartico_WT_39019_mt_data')
    
    flag = Pneumatico.try_until(browser, search_page, element) {
    
      browser.text_field(:id => 'misura').set query
      
      
      browser.execute_script(%{jQuery("select[name|='stagione']").show();})
      
      browser.select_list(:name => 'stagione').select stagione
              
      
       
      browser.button(:id => 'bottone_cerca').click
      
      sleep 0.25
      while browser.div(:id=>"tmp_loading").visible? do 
        sleep 1 
      end
      
      
      if browser.div(:id => 'tmp_noresult').present?
        puts "no results for centrogomme"
        browser.close
        return false
      end
       
      browser.table(:id => 'searchartico_WT_39019_mt_data').wait_until_present(timeout: 5)
      
      #condition = browser.table(:id => 'searchartico_WT_39019_mt_data').exists? 
      
    }
    puts flag 
    if flag 
            
      File.open('pages/centrogomme.html', 'w') {|f| f.write browser.table(:id => 'searchartico_WT_39019_mt_data').html }
                
      browser.close
      browser.quit
                
      file = File.open('pages/centrogomme.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]        
      
      i = 0
      j = 0
      document.css('tbody tr').each do |row|
        if j<max_results
          
          if row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c2').text.strip.split(" ").first == "CATENE"
            i+=1
            next
          end
          
          marca = row.at_css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c1 img').attr('src').split("/").last[0..-5].gsub("%20"," ").upcase
          nome = row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c2').text.strip
          p_netto = row.at_css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c9').text[4..-1].strip.gsub(",",".").to_f
          stock = row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c10').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c11').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c12').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c13').text.strip.to_i
          puts "CentroGomme: "+nome
          tmp_stagione = row.css('img.pdImgstagione').first['src'].split("/").last.split(".").first
          
          if tmp_stagione == "I"
            stagione = "Inverno"
          elsif tmp_stagione == "E"
            stagione = "Estate"
          else
            stagione = "4 Stagioni"
          end
            
         
          if nome[6] != "R" && nome[7] != "R"
            misura = nome.gsub("CAM.", "").split(" ").first.strip
            raggio = nome.gsub("CAM.", "").split(" ").second.strip
          else
          
            misura = nome.gsub("CAM.","").split("R").first.strip
            raggio = nome.gsub("CAM.","").split("R").second.split(" ").first
          end
          
          raggio = raggio.gsub(".","")
          misura_totale = misura+raggio
          
          
          if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "CentroGomme" ,marca: marca, misura: misura, raggio: raggio, modello: nome, fornitore: @centrogomme, prezzo_netto: p_netto, giacenza: stock, stagione: stagione)
            j+=1
          end
        end
        i+=1
      end
      
      file.close   
    else
      browser.close
      puts "No results for CentroGomme"
    end
    
  end
  
  
  def self.search_multityre(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
            
    Pneumatico.sureLoadLink(10){ browser.goto 'http://multitires.autotua.it/' }
    
    fornitore_multityre = Fornitore.where(nome: "MultiTyre").first
    browser.text_field(:name => 'username').set fornitore_multityre.user_name
            
    browser.text_field(:name => 'password').set fornitore_multityre.password
           
    browser.button(:type => 'submit').click
           
    search_page = 'http://multitires.autotua.it/interna.asp'
    element = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
    
    flag = Pneumatico.try_until(browser,search_page,element) {
      browser.iframe.text_field(:class => 'Misura_TextBox').wait_until_present
              
      browser.iframe.text_field(:class => 'Misura_TextBox').set query
      
      if stagione == "Tutte"
        id = "ContenutoPagina_ucRicerca1_cbTutti"
      elsif stagione == "Estate"
        id = "ContenutoPagina_ucRicerca1_cbEstivo"
      elsif stagione == "Inverno"
        id = "ContenutoPagina_ucRicerca1_cbInvernale"
      elsif stagione == "4 Stagioni"
        id = "ContenutoPagina_ucRicerca1_cbQuattroStagioni"
      end
              
     
      browser.iframe.checkbox(:id => id).set
              
      browser.iframe.button(:name => 'ctl00$ContenutoPagina$ucRicerca1$butCercaA').click
      
      sleep 0.25
      while browser.div(:id=>"divwait").visible? do 
        sleep 1 
      end
      
      if browser.iframe(:id => 'search1').span(:class => 'NessunArticolo').text.strip == "Articoli Trovati 0"
        puts "no results for multitires"
        browser.close
        return false
      end
      
      browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').wait_until_present(timeout: 5)
            
      
    }
    puts flag 
    if flag
          
      table = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
      File.open('pages/multitires.html', 'w') {|f| f.write table.html }
              
      browser.close
      browser.quit
                
      file = File.open('pages/multitires.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]          
      i = 0
      j = 0
      table = document.css('table.gvTheGrid')
      table.css('tbody tr.Riga').each do |row|
        if i.even? && j<max_results*2
          
          if row.css('td.Catalogo.allinea div').text != ""
            marca = row.css('td.Catalogo.allinea div').text
          else
            marca = row.at_css('td.Catalogo.allinea img').attr("title")
          end
                    
          nome = row.css('div.DescrizioneArticolo').text
          p_netto = row.css('td.CatalogoDisp.ALT.allinea')[1].text.strip.gsub(",",".").to_f.round(2)
          stock = row.css('td.CatalogoDisp.allinea strong')[0].text.to_i + row.css('td.CatalogoDisp.allinea strong')[1].text.to_i + row.css('td.CatalogoDisp.allinea strong span').text.to_i
          misura = nome.gsub('-','R').split('R',2).first.strip.split(" ").first.strip
          raggio = nome.gsub('-','R').split('R',2).second.split(" ").first.strip
          
          puts "MultiTires: "+nome
          # CONTROLLO SULLA VALIDITA' DEL CAMPO RAGGIO --- DA SISTEMARE PER ALCUNI VALORI
          
          if raggio.to_i.to_s != raggio
            raggio = nome.split(" ")[2]
          end
          
          raggio = raggio.gsub(".","")
          
          tmp_stagione = row.css('td.CatalogoDisp.allinea img').first['src'].split("/").last.split(".").first
          
          misura_totale = misura+raggio
          if tmp_stagione == "sun"
            stagione = "Estate"
          elsif tmp_stagione == "snow"
            stagione = "Inverno"
          else
            stagione = "4 Stagioni"
          end
          
          if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp)
            Pneumatico.create(nome_fornitore: "MultiTires", marca: marca, misura: misura, raggio: raggio, modello: nome, fornitore: @multitires, prezzo_netto: p_netto, giacenza: stock, stagione: stagione)
            j+=1
          end
        end 
        i+=1
      end
        
      file.close
    
    else
      browser.close
      puts "no results for multitires"
    end    
  end
  
  def self.search_maxtyre(query,stagione,max_results)
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    count = 0
    while true
      begin
        if count>2
          flag = false
          break
        end
          
        Pneumatico.sureLoadLink(10){ browser.goto 'http://web.maxtyre.it/' }
                   
        puts "page loaded"
        
        fornitore_maxtyre = Fornitore.where(nome: "MaxTyre").first
        browser.text_field(:name => 'username').set fornitore_maxtyre.user_name
                    
        browser.text_field(:name => 'password').set fornitore_maxtyre.password
                   
        browser.link(:id => 'button-1017').click
          
        sleep 3
        puts "login effettuato"
          
        browser.link(:id =>"button-1026").click
            
        puts "Bottone ricerca premuto" 
          
        browser.text_field(:name => 'codRic').set query
        puts "query settata"
        
       
        index = 0
        browser.links.each do |link|
          if index>20
            
            if link.text[1..-1] == "Ricerca"
            
              if stagione == "Tutte"
                  puts "clicking link"
                  browser.send_keys :enter
                  #browser.links[index].click
              elsif stagione == "Estate"
                browser.links[index-3].click
              elsif stagione == "Inverno"
                browser.links[index-2].click
              else
                browser.links[index-1].click
              end
            end
          end
          index+=1
        end
  
        puts "sleeeping"
        
        sleep 5 
        if browser.div(:class => 'x-grid-item-container').text.strip == ""
          flag = false
          break
        end
        
        browser.table(:class => 'x-grid-item').wait_until_present(timeout: 20)
        
        if browser.table(:class => 'x-grid-item').present?
          flag = true
          break
        end
      rescue Watir::Exception::UnknownObjectException
        puts "Exception, Retrying"
        count+=1
        retry
      end
    end
    if flag
      table = []
      #max_scrolls = 10
      #puts browser.div(:class => "x-grid-item-container").tables.html
      table = Pneumatico.maxtyre_create_table(browser)

      
      
     
      
      File.open('pages/maxtyre.html', 'w') {|f| table.each { |e| f.write(e) } }
              
      browser.close
      browser.quit
                
      file = File.open('pages/maxtyre.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]          
      #table = document.css('table x-grid-item')
      document.css('table.x-grid-item tr').each do |row|
        if row.css('td.x-grid-cell img').first["title"] != ""
          marca = row.css('td.x-grid-cell img').first["title"].split(":").second.strip
        else
          marca = ""
        end
       
        
        modello = row.css("td.x-grid-cell")[1].text
        
        puts "MaxTyre: "+modello
        tmp_stagione = row.css("td.x-grid-cell")[10].css("img").first['src'].split("/").last.split(".").first
        if tmp_stagione == "sole"
          stagione = "Estate"
        elsif tmp_stagione == "snow"
          stagione = "Inverno"
        else
          stagione = "4 Stagioni"
        end
        
        prezzo_netto = row.css("td.x-grid-cell")[13].text.strip.gsub(",",".").to_f.round(2)
     
        
        giacenza = row.css("td.x-grid-cell")[15].text.strip.to_i + row.css("td.x-grid-cell")[16].text.strip.to_i 
        
       
        misura = modello.split(" ").first+"/"+modello.split(" ").second[0..1]
        raggio = modello[6..-1].strip.split(" ").first.gsub(/[^0-9]/, '')
        
        
        misura_totale = misura + raggio
       
        if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp)
            Pneumatico.create(nome_fornitore: "MaxTyre", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @maxtyre, prezzo_netto: prezzo_netto, giacenza: giacenza, stagione: stagione)
        end
      end
      file.close
    else
      browser.close
      puts "no results for maxtyre"
    end    
  end
    
    
  def self.maxtyre_create_table(browser)
    last_tmp = ""
    i=0
    table = []
    flag = false
    j = 0
    browser.div(:class => "x-grid-item-container").tables.each do |item|
      table.push item.html
    end
    puts 
    while j<50
      puts flag
        if flag == true
          puts "Devo ritornaaa"
          break
        end
      begin
          container = browser.div(:class => "x-grid-item-container")
          if last_tmp == container.tables.last.text
            puts "no more results"
            break
          else
            container.tables.each do |item|
              if !(table.include? item)
                table.push item.html
              end
            end
          end
              
          puts "scrolling"
          last_tmp = container.tables.last.text
          container.tables.last.wd.location_once_scrolled_into_view
          sleep 0.20
         
          j+=1
      rescue Watir::Exception::UnknownObjectException
        puts "End"
        flag = true
        next
      end
      
    end
    return table
  end
  def self.try_until(browser, search_page, element)
    wait = true
    i = 0
    while (wait == true)
    # DA PARAMETRIZZARE PRENDENDO COME ULTERIORE PARAMETRO UN ELEMENTO CHE SI TROVA QUANDO NON CI SONO RISULTATI
      
      if i>3
        return false
      else
        begin
          yield
          if (element.exists?)
            puts "Success"
            #puts element.html
            wait = false
            return true
          end
          
        rescue Selenium::WebDriver::Error::ElementNotDisplayedError
        rescue Selenium::WebDriver::Error::ObsoleteElementError
        rescue Watir::Exception::UnknownObjectException
        rescue Timeout::Error
        rescue Watir::Wait::TimeoutError
        rescue Watir::Exception::UnknownFrameException
        rescue Watir::Exception::UnknownObjectException
          
          puts "Retrying.."
          sleep 1
          Pneumatico.sureLoadLink(10){ browser.goto search_page }
        end
      end
      i+=1
    end
  end	
end
